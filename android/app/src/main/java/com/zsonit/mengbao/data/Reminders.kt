package com.zsonit.mengbao.data

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.zsonit.mengbao.MainActivity
import com.zsonit.mengbao.model.AppSettings
import com.zsonit.mengbao.model.Child
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * 本机提醒（量身高 / 待办到期），对应 iOS 的 NotificationManager。
 * 用 AlarmManager 排「允许打盹」的不精确闹钟：无需任何特殊权限，
 * 深度休眠时最多延迟十几分钟，对"早上 9 点提醒"这类场景足够。
 * 每次数据变动 / 每次启动 / 开机完成都会重排一遍，保证提醒和当前数据一致
 * （已完成的待办不再提醒、清空数据后提醒全部取消）。
 */
object Reminders {

    const val CHANNEL_ID = "mb.reminders"

    private const val PREFS = "mb.reminders"
    private const val KEY_IDS = "alarm_ids"
    private const val GROWTH_PREFIX = "mb.growth."
    private const val TODO_PREFIX = "mb.todo."
    private const val BDAY_PREFIX = "mb.bday."
    /** 每日补剂 / 用药提醒（开关 + 自定义时间点，每天重复） */
    private const val SUPP_PREFIX = "mb.supp."
    private const val MED_PREFIX = "mb.med."
    /** 接种提醒（按每剂「安排」里的计划） */
    private const val VAX_PREFIX = "mb.vax."
    /** 定期测量一次往前排几个周期（App 长期不打开也能撑住） */
    private const val GROWTH_SLOTS = 8
    /** 待办提醒最多排多少条 */
    private const val TODO_LIMIT = 20

    private val handler = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null

    // MARK: 初始化

    fun init(context: Context) {
        val app = context.applicationContext
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "宝宝提醒", NotificationManager.IMPORTANCE_HIGH).apply {
                        description = "量身高、待办到期的提醒"
                    },
                )
            }
        }
    }

    fun permissionGranted(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    // MARK: 总排程

    /** 数据变动后重排：防抖 600ms，连续写入不会反复取消/重建闹钟（对应 iOS 的 0.6s 防抖） */
    fun reschedule(context: Context) {
        val app = context.applicationContext
        pending?.let { handler.removeCallbacks(it) }
        val r = Runnable { runCatching { rescheduleNow(app) }.onFailure { AppLog.e("Remind", "重排提醒失败：$it") } }
        pending = r
        handler.postDelayed(r, 600)
    }

    /** 立即重排（启动 / 开机完成时用） */
    fun rescheduleNow(context: Context) {
        val app = context.applicationContext
        cancelScheduled(app)
        val s = Store.settings
        val children = Store.state.children
        val anyBday = children.any { it.birthdayRemind != false }
        val hasVaxPlan = children.any { !(it.plans ?: emptyMap()).isEmpty() }
        if (!s.growthReminderOn && !s.todoReminderOn && !anyBday &&
            !s.suppReminderOn && !s.medReminderOn && !hasVaxPlan
        ) return
        if (!permissionGranted(app)) return
        val ids = mutableSetOf<String>()
        if (s.growthReminderOn) ids += scheduleGrowth(app, children, s)
        if (s.todoReminderOn) ids += scheduleTodos(app, children, s)
        ids += scheduleBirthdays(app, children)
        ids += scheduleDose(app, s)
        ids += scheduleVax(app, children)
        saveIds(app, ids)
        AppLog.i("Remind", "提醒已排：测量 ${ids.count { it.startsWith(GROWTH_PREFIX) }} 条，待办 ${ids.count { it.startsWith(TODO_PREFIX) }} 条，生日 ${ids.count { it.startsWith(BDAY_PREFIX) }} 条，用药补剂 ${ids.count { it.startsWith(MED_PREFIX) || it.startsWith(SUPP_PREFIX) }} 条")
    }

    private fun alarm(context: Context): AlarmManager =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun storedIds(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_IDS, emptySet()) ?: emptySet()

    private fun saveIds(context: Context, ids: Set<String>) {
        prefs(context).edit().putStringSet(KEY_IDS, ids).apply()
    }

    /** 取消当前排着的所有提醒 */
    private fun cancelScheduled(context: Context) {
        val am = alarm(context)
        storedIds(context).forEach { id ->
            am.cancel(pendingIntent(context, id, "", ""))
        }
    }

    // MARK: 定期测量提醒

    private fun scheduleGrowth(context: Context, children: List<Child>, s: AppSettings): Set<String> {
        val am = alarm(context)
        val ids = mutableSetOf<String>()
        val now = LocalDateTime.now()
        val step = maxOf(1, s.growthReminderDays).toLong()

        children.forEach { child ->
            // 基准日：这个宝宝最近一次生长记录；一次都没记过就从今天算起
            val base = child.records.maxByOrNull { it.date }?.date ?: LocalDate.now()
            var cursor = base
            var slot = 0
            var guard = 0

            while (slot < GROWTH_SLOTS && guard < 400) {
                guard += 1
                cursor = cursor.plusDays(step)
                val fire = cursor.atTime(s.growthReminderHour, s.growthReminderMinute)
                if (!fire.isAfter(now)) continue   // 已经过去的周期直接跳过

                val days = ChronoUnit.DAYS.between(base, cursor)
                val id = GROWTH_PREFIX + child.id + "." + slot
                if (setAlarm(context, am, id, fire,
                        "该给${child.name}量身高体重了",
                        "离上次测量 $days 天啦。脱鞋靠墙站直量一次，生长曲线才连得上。")
                ) {
                    ids.add(id)
                    slot += 1
                }
            }
        }
        return ids
    }

    // MARK: 生日提醒（当天 / 提前 N 天，两个独立开关，时刻各自可调）

    private fun scheduleBirthdays(context: Context, children: List<Child>): Set<String> {
        val am = alarm(context)
        val ids = mutableSetOf<String>()
        val now = LocalDateTime.now()

        children.forEach { child ->
            val sameDayOn = child.bdaySameDayEnabled
            val advOn = child.bdayAdvanceEnabled
            if (!sameDayOn && !advOn) return@forEach
            val advDays = child.bdayAdvanceDaysEffective
            val birth = child.birthDate

            // 之后两年的生日
            for (yearOffset in 0..1) {
                var next = LocalDate.of(now.year + yearOffset, birth.monthValue, birth.dayOfMonth)
                if (next.isBefore(now.toLocalDate())) continue
                val age = ChronoUnit.YEARS.between(birth, next)

                val targets = mutableListOf<Triple<String, LocalDate, String>>()
                if (sameDayOn) {
                    targets.add(
                        Triple("d0", next, "🎂 今天是${child.name}的生日|祝${child.name} $age 岁生日快乐，记得吃蛋糕拍照记录！"),
                    )
                }
                if (advOn) {
                    val whenTxt = if (advDays == 1) "明天" else "$advDays 天后"
                    targets.add(
                        Triple("d1", next.minusDays(advDays.toLong()), "🎁 ${whenTxt}是${child.name}的生日|${whenTxt}${child.name}就 $age 岁啦，礼物和蛋糕可以提前准备。"),
                    )
                }
                targets.forEach { (tag, day, text) ->
                    val minutes = if (tag == "d0") child.bdaySameDayMinutes else child.bdayAdvanceMinutes
                    val fire = day.atTime(LocalTime.of(minutes / 60, minutes % 60))
                    if (fire.isAfter(now)) {
                        val parts = text.split("|")
                        val id = BDAY_PREFIX + child.id + ".y" + yearOffset + "." + tag
                        if (setAlarm(context, am, id, fire, parts[0], parts[1])) ids.add(id)
                    }
                }
            }
        }
        return ids
    }

    // MARK: 待办到期提醒

    private fun scheduleTodos(context: Context, children: List<Child>, s: AppSettings): Set<String> {
        val am = alarm(context)
        val ids = mutableSetOf<String>()
        val now = LocalDateTime.now()

        outer@ for (child in children) {
            for (todo in child.todos) {
                if (todo.done) continue
                val due = todo.due ?: continue
                if (todo.id in s.mutedTodoReminders) continue  // 本机静音的待办不响
                if (ids.size >= TODO_LIMIT) break@outer

                // 截止前一天 20:00 先预告一次
                val pre = due.minusDays(1).atTime(20, 0)
                if (pre.isAfter(now)) {
                    val id = TODO_PREFIX + child.id + "." + todo.id + ".pre"
                    if (setAlarm(context, am, id, pre, "明天到期：${todo.title}", "是 ${child.name} 的待办，别忘了。")) {
                        ids.add(id)
                    }
                }
                // 当天 09:00 再提醒一次
                val onDay = due.atTime(9, 0)
                if (onDay.isAfter(now)) {
                    val id = TODO_PREFIX + child.id + "." + todo.id + ".due"
                    if (setAlarm(context, am, id, onDay, "今天到期：${todo.title}", "是 ${child.name} 的待办，该去办啦。")) {
                        ids.add(id)
                    }
                }
            }
        }
        return ids
    }

    // MARK: 每日补剂 / 用药提醒（开关 + 任意多个时间点，每天重复）

    private class DoseGroup(
        val prefix: String,
        val on: Boolean,
        val times: List<String>,
        val title: String,
        val body: String,
    )

    private fun scheduleDose(context: Context, s: AppSettings): Set<String> {
        val am = alarm(context)
        val ids = mutableSetOf<String>()
        val now = LocalDateTime.now()
        val groups = listOf(
            DoseGroup(MED_PREFIX, s.medReminderOn, s.medReminderTimes,
                "💊 该吃药啦", "到点给宝宝喂药，吃完记得在 App 里记一笔。"),
            DoseGroup(SUPP_PREFIX, s.suppReminderOn, s.suppReminderTimes,
                "🥛 该吃补剂啦", "到点啦，今天的补剂别忘了，吃完记得记一笔。"),
        )
        for (g in groups) {
            if (!g.on) continue
            for (raw in g.times) {
                val parts = raw.split(":")
                if (parts.size != 2) continue
                val h = parts[0].toIntOrNull() ?: continue
                val m = parts[1].toIntOrNull() ?: continue
                if (h !in 0..23 || m !in 0..59) continue
                val id = g.prefix + "%02d.%02d".format(h, m)
                var fire = now.toLocalDate().atTime(h, m)
                if (!fire.isAfter(now)) fire = fire.plusDays(1)
                if (setAlarm(context, am, id, fire, g.title, g.body)) ids.add(id)
            }
        }
        return ids
    }

    /**
     * 响过一次的「每日提醒」不会自己重复，这里排下一天。
     * id 形如 mb.med.09.30，时间点就从 id 里解出来。
     */
    fun rearmIfDose(context: Context, id: String, title: String, body: String) {
        val core = when {
            id.startsWith(MED_PREFIX) -> id.removePrefix(MED_PREFIX)
            id.startsWith(SUPP_PREFIX) -> id.removePrefix(SUPP_PREFIX)
            else -> return
        }
        val p = core.split(".")
        if (p.size != 2) return
        val h = p[0].toIntOrNull() ?: return
        val m = p[1].toIntOrNull() ?: return
        val now = LocalDateTime.now()
        var fire = now.toLocalDate().atTime(h, m)
        if (!fire.isAfter(now)) fire = fire.plusDays(1)
        runCatching { setAlarm(context, alarm(context), id, fire, title, body) }
    }

    // MARK: 接种提醒（按每剂「安排」里的计划：提前 N 天，带地点）

    private fun scheduleVax(context: Context, children: List<Child>): Set<String> {
        val am = alarm(context)
        val ids = mutableSetOf<String>()
        val now = LocalDateTime.now()

        for (child in children) {
            val plans = child.plans ?: continue
            if (plans.isEmpty()) continue
            val doses = GrowthMath.schedule(child)
            for (dose in doses) {
                val plan = plans[dose.key] ?: continue
                if (!plan.remindOn) continue
                if (dose.status == Dose.Status.DONE || dose.status == Dose.Status.LOCKED) continue
                val target = plan.date ?: dose.dueDate.atTime(9, 0)
                val fire = target.minusDays(plan.advanceEffective.toLong())
                if (!fire.isAfter(now)) continue
                val body = buildString {
                    append("${dose.vaccine.name}（${dose.vaccine.dose}）")
                    if (plan.place.isNotEmpty()) append("，地点：${plan.place}")
                    append("，记得带《预防接种证》。")
                }
                val id = VAX_PREFIX + dose.key
                if (setAlarm(context, am, id, fire, "💉 ${child.name}：该接种疫苗啦", body)) ids.add(id)
            }
        }
        return ids
    }

    // MARK: 闹钟底层

    private fun setAlarm(context: Context, am: AlarmManager, id: String, fire: LocalDateTime, title: String, body: String): Boolean {
        val millis = fire.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        if (millis <= System.currentTimeMillis()) return false
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, millis, pendingIntent(context, id, title, body))
        return true
    }

    private fun pendingIntent(context: Context, id: String, title: String, body: String): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra("id", id)
            putExtra("title", title)
            putExtra("body", body)
        }
        return PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

// MARK: - 到点响铃

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!Reminders.permissionGranted(context)) return
        val id = intent.getStringExtra("id") ?: return
        val title = intent.getStringExtra("title") ?: return
        val body = intent.getStringExtra("body") ?: ""

        Reminders.init(context)
        val tap = PendingIntent.getActivity(
            context,
            id.hashCode(),
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n = NotificationCompat.Builder(context, Reminders.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(tap)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(id.hashCode(), n) }
        // 每日补剂/用药提醒：响完立刻排下一天
        runCatching { Reminders.rearmIfDose(context, id, title, body) }
    }
}

// MARK: - 开机后重排（闹钟重启会丢，开机补排）

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        runCatching {
            Store.init(context)
            Reminders.init(context)
            Reminders.rescheduleNow(context)
        }
    }
}
