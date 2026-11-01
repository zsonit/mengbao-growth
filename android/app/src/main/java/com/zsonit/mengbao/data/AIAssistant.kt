package com.zsonit.mengbao.data

import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.FeedLog
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.model.Sex
import com.zsonit.mengbao.model.SizeRecord
import com.zsonit.mengbao.model.TodoItem
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.Locale

// AI 语音指令：把一句话变成 App 里的操作。
// 语音识别 → 大模型按固定 JSON 协议返回「怎么说 + 做什么」→ 本地校验后写进 Store（写入即触发同步）→ 展示结果，可撤销。
// 模型只负责理解，不直接碰数据；数值都有本地校验，宁可少记也不瞎记。

data class AIActionItem(
    val label: String,
    val undo: () -> Unit,
)

data class AIPlan(
    val reply: String,
    val items: List<AIActionItem>,
    val openPage: String? = null,
)

object AIAssistant {

    val pages = listOf(
        "home" to "首页", "feed" to "喂养", "trends" to "成长趋势", "history" to "记录历史",
        "todo" to "待办清单", "vaccine" to "接种", "size" to "鞋服尺码", "growth" to "生长曲线",
        "teeth" to "换牙", "profile" to "我的",
    )

    private val HM = DateTimeFormatter.ofPattern("HH:mm")
    private val YMD = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    private val YMDHM = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
    private val WEEK = listOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")

    // MARK: 提示词

    fun systemPrompt(child: Child?): String {
        val now = LocalDateTime.now()
        val today = now.toLocalDate()
        val tomorrow = today.plusDays(1)
        val weekday = WEEK[(today.dayOfWeek.value + 6) % 7]

        var baby = "（还没有宝宝档案）"
        var todayStat = ""
        if (child != null) {
            baby = "${GrowthMath.ageText(child.birthDate)}，${if (child.sex == Sex.GIRL) "女孩" else "男孩"}"
            val feeds = child.feeds.filter { it.date == today }
            val sleep = feeds.filter { it.kind == FeedLog.Kind.SLEEP }.sumOf { it.minutes ?: 0 }
            val milk = feeds.filter { it.kind == FeedLog.Kind.BOTTLE }.sumOf { it.ml ?: 0.0 }.toInt()
            val diaper = feeds.count { it.kind == FeedLog.Kind.DIAPER }
            val solid = feeds.count { it.kind == FeedLog.Kind.SOLID }
            val pump = feeds.filter { it.kind == FeedLog.Kind.PUMPING }.sumOf { it.ml ?: 0.0 }.toInt()
            todayStat = "今天已记：睡眠 $sleep 分钟、奶量 $milk ml、尿布 $diaper 次、吸奶 $pump ml、辅食 $solid 次。"
        }

        val pageList = pages.joinToString("|") { it.first }

        return """
你是「萌宝成长」App 里的中文语音助手。家长说一句话，你要判断他想做什么：能变成 App 操作的就执行，只是提问就用一句话回答。宝宝：$baby。
现在是 ${now.format(YMDHM)}（$weekday）。${todayStat}今天是 $today，明天是 $tomorrow。

只输出一个 JSON 对象，不要输出任何其它文字，不要用 ``` 包裹：
{"reply":"给家长看的一句话，口语，不超过 40 字","actions":[...]}

actions 只能是下面几种，没有要执行的就给 []：
1) 喂养/护理记录
{"type":"feed","kind":"sleep|breast|bottle|pumping|diaper|solid|supplement|temp|custom",
 "minutes":整数分钟或null,"ml":数字或null,"side":"左|右|双侧或null",
 "diaperKind":"小便|大便|混合或null","value":体温等数字或null,"note":"简短备注可为空","time":"HH:mm或null"}
2) 待办
{"type":"todo","title":"要做什么","due":"yyyy-MM-dd 或 null"}
3) 生长测量（身高体重头围脚长，单位 cm / kg）
{"type":"growth","height":null,"weight":null,"headCirc":null,"footLength":null,"note":""}
4) 鞋服尺码（只要脚长和身高就够）
{"type":"size","footLength":null,"height":null,"note":""}
5) 打开页面
{"type":"page","page":"$pageList"}

规则：
- 一句话里有多件事，就拆成多条 actions，按说的顺序排。
- 时长换算：半小时=30，一个多小时=70，两小时=120，一刻钟=15。
- 数量换算：一百二=120，两百=200，"毫升/ml/CC"都是 ml。
- 只写家长明确说过的数值，没说就填 null，绝对不要自己编。
- 时间：只说"刚才/刚刚/今天"就填 null；说了"早上七点""下午三点半""晚上八点"就换成 24 小时制 HH:mm；说了"昨天"就在 note 里注明【昨天】。
- 家长只是在问问题（例如"睡得够不够""能不能加辅食"），actions 给 []，答案写在 reply 里。
- 家长在反映 App 本身的问题（界面显示不全、有缺口、闪退、卡、按钮点不动等），不是在记录宝宝数据：actions 给 []，reply 只回一句「收到，这条记下了，会尽快修」，绝不猜测技术原因，不要建议去改手机设置、显示大小或升级系统。
- 健康相关：发烧≥38.5℃、抽搐、呼吸困难、精神差、持续呕吐 → 提醒尽快就医；不确定就直说不知道，不要编。
- reply 里最多一个表情符号，不要 Markdown、不要分点罗列。

示例：
家长："宝宝十点喝了120的奶" → {"reply":"记下了：10:00 瓶喂 120 ml","actions":[{"type":"feed","kind":"bottle","ml":120,"minutes":null,"side":null,"diaperKind":null,"value":null,"note":"","time":"10:00"}]}
家长："刚换了尿布是大便，然后明天记得买纸尿裤" → {"reply":"记下大便一次，明天提醒你买纸尿裤","actions":[{"type":"feed","kind":"diaper","minutes":null,"ml":null,"side":null,"diaperKind":"大便","value":null,"note":"","time":null},{"type":"todo","title":"买纸尿裤","due":"$tomorrow"}]}
家长："宝宝今天睡得怎么样" → {"reply":"今天一共睡了 2 小时 10 分钟，比昨天略少，晚上可以早点哄睡。","actions":[]}
        """.trimIndent()
    }

    // MARK: 请求 + 执行

    suspend fun interpret(text: String, model: String): AIPlan {
        val raw = AIClient.complete(model, systemPrompt(Store.current), text)
        val (reply, actions) = parse(raw)
        val applied = execute(actions)
        return AIPlan(reply = reply, items = applied.first, openPage = applied.second)
    }

    /** 模型偶尔会裹 ``` 或加一句话，这里只抠第一个 { 到最后一个 } */
    fun parse(raw: String): Pair<String, List<JSONObject>> {
        val text = raw.trim().removePrefix("```json").removePrefix("```").removeSuffix("```").trim()
        val start = text.indexOf('{')
        val end = text.lastIndexOf('}')
        if (start < 0 || end <= start) return fallback(text) to emptyList()
        val json = text.substring(start, end + 1)
        val obj = runCatching { JSONObject(json) }.getOrNull() ?: return fallback(text) to emptyList()
        val reply = obj.optString("reply").ifBlank { fallback(text) }
        val arr = obj.optJSONArray("actions") ?: JSONArray()
        val actions = (0 until arr.length()).mapNotNull { arr.optJSONObject(it) }
        return reply to actions
    }

    private fun fallback(text: String): String {
        val clean = text.trim()
        return if (clean.isEmpty()) "我没太听懂，再说一次？" else clean.take(160)
    }

    private fun execute(actions: List<JSONObject>): Pair<List<AIActionItem>, String?> {
        val items = mutableListOf<AIActionItem>()
        var page: String? = null
        for (a in actions) {
            when (a.optString("type")) {
                "feed" -> applyFeed(a)?.let { items.add(it) }
                "todo" -> applyTodo(a)?.let { items.add(it) }
                "growth" -> applyGrowth(a)?.let { items.add(it) }
                "size" -> applySize(a)?.let { items.add(it) }
                "page" -> {
                    val p = a.optString("page")
                    if (pages.any { it.first == p }) page = p
                }
            }
        }
        return items to page
    }

    private fun num(a: JSONObject, key: String): Double? {
        if (a.isNull(key)) return null
        a.optDouble(key, Double.NaN).let { if (!it.isNaN()) return it }
        return a.optString(key).replace(",", "").toDoubleOrNull()
    }

    private fun timeOf(a: JSONObject): LocalTime {
        val t = a.optString("time")
        if (t.isBlank()) return LocalTime.now()
        return runCatching { LocalTime.parse(t, HM) }.getOrDefault(LocalTime.now())
    }

    private fun kindOf(raw: String): FeedLog.Kind? = when (raw) {
        "sleep" -> FeedLog.Kind.SLEEP
        "breast" -> FeedLog.Kind.BREAST
        "bottle" -> FeedLog.Kind.BOTTLE
        "pumping" -> FeedLog.Kind.PUMPING
        "diaper" -> FeedLog.Kind.DIAPER
        "solid" -> FeedLog.Kind.SOLID
        "supplement" -> FeedLog.Kind.SUPPLEMENT
        "temp" -> FeedLog.Kind.TEMP
        "custom" -> FeedLog.Kind.CUSTOM
        else -> null
    }

    private fun applyFeed(a: JSONObject): AIActionItem? {
        val kind = kindOf(a.optString("kind")) ?: return null
        val time = timeOf(a)
        val today = LocalDate.now()
        var minutes: Int? = null
        var ml: Double? = null
        var value: Double? = null
        var side: String? = null
        var diaperKind: String? = null

        when (kind) {
            FeedLog.Kind.SLEEP, FeedLog.Kind.BREAST -> {
                val m = num(a, "minutes") ?: return null
                if (m <= 0 || m >= 24 * 60) return null
                minutes = m.toInt()
            }
            FeedLog.Kind.BOTTLE, FeedLog.Kind.PUMPING -> {
                val v = num(a, "ml") ?: return null
                if (v <= 0 || v >= 2000) return null
                ml = v
            }
            FeedLog.Kind.TEMP -> {
                val v = num(a, "value") ?: return null
                if (v <= 30 || v >= 45) return null
                value = v
            }
            FeedLog.Kind.DIAPER -> diaperKind = a.optString("diaperKind").ifBlank { "小便" }
            else -> Unit
        }
        if (kind == FeedLog.Kind.BREAST) side = a.optString("side").ifBlank { null }

        val log = FeedLog(
            date = today,
            time = time,
            kind = kind,
            minutes = minutes,
            ml = ml,
            side = side,
            diaperKind = diaperKind,
            value = value,
            note = a.optString("note"),
        )
        Store.addFeed(log)
        val label = buildString {
            append(kind.title)
            val sum = when (kind) {
                FeedLog.Kind.SLEEP, FeedLog.Kind.BREAST -> "${minutes ?: 0} 分钟"
                FeedLog.Kind.BOTTLE, FeedLog.Kind.PUMPING -> "${(ml ?: 0.0).toInt()} ml"
                FeedLog.Kind.DIAPER -> diaperKind ?: "小便"
                FeedLog.Kind.TEMP -> String.format(Locale.US, "%.1f ℃", value ?: 0.0)
                else -> a.optString("note")
            }
            if (sum.isNotBlank()) append(" · ").append(sum)
            append(" · ").append(time.format(HM))
        }
        return AIActionItem(label) { Store.deleteFeed(log.id) }
    }

    private fun applyTodo(a: JSONObject): AIActionItem? {
        val title = a.optString("title").trim()
        if (title.isEmpty()) return null
        val due = a.optString("due").takeIf { it.isNotBlank() }
            ?.let { runCatching { LocalDate.parse(it, YMD) }.getOrNull() }
        val todo = TodoItem(title = title, due = due)
        Store.addTodo(todo)
        val label = if (due == null) "待办 · $title" else "待办 · $title（${GrowthMath.shortDate(due)}）"
        return AIActionItem(label) { Store.deleteTodo(todo.id) }
    }

    private fun applyGrowth(a: JSONObject): AIActionItem? {
        val h = num(a, "height")?.takeIf { it in 30.0..200.0 }
        val w = num(a, "weight")?.takeIf { it in 0.5..80.0 }
        val hc = num(a, "headCirc")?.takeIf { it in 20.0..70.0 }
        val fl = num(a, "footLength")?.takeIf { it in 3.0..40.0 }
        if (h == null && w == null && hc == null && fl == null) return null
        val record = GrowthRecord(
            date = LocalDate.now(),
            height = h, weight = w, footLength = fl, headCirc = hc,
            note = a.optString("note"),
        )
        Store.addRecord(record)
        val parts = buildList {
            h?.let { add(String.format(Locale.US, "身高 %.1f cm", it)) }
            w?.let { add(String.format(Locale.US, "体重 %.2f kg", it)) }
            hc?.let { add(String.format(Locale.US, "头围 %.1f cm", it)) }
            fl?.let { add(String.format(Locale.US, "脚长 %.1f cm", it)) }
        }
        return AIActionItem("生长测量 · " + parts.joinToString("、")) { Store.deleteRecord(record.id) }
    }

    private fun applySize(a: JSONObject): AIActionItem? {
        val fl = num(a, "footLength")?.takeIf { it in 3.0..40.0 }
        val h = num(a, "height")?.takeIf { it in 30.0..200.0 }
        if (fl == null && h == null) return null
        val record = SizeRecord(date = LocalDate.now(), footLength = fl, height = h, note = a.optString("note"))
        Store.addSize(record)
        val parts = buildList {
            fl?.let { add(String.format(Locale.US, "脚长 %.1f cm", it)) }
            h?.let { add(String.format(Locale.US, "身高 %.1f cm", it)) }
        }
        val saved = Store.current?.sizes?.firstOrNull {
            it.date == record.date && it.footLength == fl && it.height == h
        }
        return AIActionItem("鞋服尺码 · " + parts.joinToString("、")) {
            if (saved != null) Store.deleteSize(saved.id)
        }
    }
}
