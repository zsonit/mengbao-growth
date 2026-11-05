package com.zsonit.mengbao.data

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.DosePlan
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * 接种计划同步到系统日历：把「安排」好的接种计划写成一条日历事件（开始前 1 小时提醒）。
 * 同一剂同一时间只写一次：本地记录已写入的 key，重复点「同步」不会建重复事件。
 * 需要 WRITE_CALENDAR 运行时权限（Android M+）。
 */
object CalendarSync {

    private const val PREFS = "mb.cal"
    private const val KEY_SYNCED = "synced_keys"

    fun permissionGranted(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    /** 计划的目标时刻（指定了就用指定时刻，否则当天 09:00） */
    fun targetDate(dose: Dose, plan: DosePlan): LocalDateTime =
        plan.date ?: dose.dueDate.atTime(9, 0)

    private fun syncedSet(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_SYNCED, emptySet()) ?: emptySet()

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * 把一剂接种计划写进系统日历。返回 null = 成功（或已写过），否则为错误描述。
     * 调用前先用 [permissionGranted] 检查权限。
     */
    fun addDoseEvent(context: Context, child: Child, dose: Dose, plan: DosePlan): String? {
        if (!permissionGranted(context)) return "没有日历权限，请在系统设置里允许日历权限"
        val target = targetDate(dose, plan)
        val dedupe = "${child.id}.${dose.key}.${target.toString()}"
        if (syncedSet(context).contains(dedupe)) return null

        return try {
            val calId = defaultCalendarId(context)
                ?: return "手机上没有可用的日历账户，请先在系统日历 App 里添加一个账户"
            val extra = Standards.extraByCode[dose.vaccine.code]
            val startMillis = target.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

            val notes = buildString {
                append("萌宝成长 · 接种计划\n")
                extra?.first?.let { append("预防：$it\n") }
                append("接种方式：${dose.vaccine.route}\n")
                extra?.second?.let { append("剂量：$it\n") }
                if (plan.place.isNotEmpty()) append("地点：${plan.place}\n")
                if (plan.note.isNotEmpty()) append("备注：${plan.note}\n")
            }

            val values = ContentValues().apply {
                put(CalendarContract.Events.CALENDAR_ID, calId)
                put(CalendarContract.Events.TITLE, "接种：${dose.vaccine.name}（${dose.vaccine.dose}）· ${child.name}")
                put(CalendarContract.Events.DESCRIPTION, notes)
                put(CalendarContract.Events.DTSTART, startMillis)
                put(CalendarContract.Events.DTEND, startMillis + 3600_000L)
                put(CalendarContract.Events.EVENT_TIMEZONE, ZoneId.systemDefault().id)
                put(CalendarContract.Events.HAS_ALARM, true)
            }
            val uri = context.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
                ?: return "写入日历失败"
            // 事件开始前 1 小时提醒
            val eventId = ContentUris.parseId(uri)
            val reminder = ContentValues().apply {
                put(CalendarContract.Reminders.EVENT_ID, eventId)
                put(CalendarContract.Reminders.MINUTES, 60)
                put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
            }
            runCatching { context.contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, reminder) }

            prefs(context).edit().putStringSet(KEY_SYNCED, syncedSet(context) + dedupe).apply()
            null
        } catch (e: Exception) {
            "写入日历失败：${e.message ?: "未知错误"}"
        }
    }

    /** 取第一个可写日历的 id */
    private fun defaultCalendarId(context: Context): Long? {
        return runCatching {
            val uri = CalendarContract.Calendars.CONTENT_URI
            val projection = arrayOf(CalendarContract.Calendars._ID, CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL)
            context.contentResolver.query(uri, projection, null, null, null)?.use { cur ->
                while (cur.moveToNext()) {
                    val id = cur.getLong(0)
                    val level = cur.getInt(1)
                    if (level >= CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR) return id
                }
            }
            null
        }.getOrNull()
    }
}
