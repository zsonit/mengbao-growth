package com.zsonit.mengbao.data

import java.time.LocalDate

/** 一句「用嘴说出来的待办」 */
data class TodoDraft(
    val title: String,
    val due: LocalDate?,
)

/**
 * 待办语音解析：一整段话 → 若干条待办，顺带识别「明天 / 下周三 / 3 天后 / 10月8号」这类日期。
 *
 * 和记喂养的 [VoiceParser] 分开：那边按动作切段（喝/睡/尿/体温），
 * 这里按标点和口头连接词切，因为「记得买维生素 D3 和钙片」这种句子不能被拆成两条。
 */
object TodoParser {

    private val delimiters = Regex("[。！？；,.!?;\\n\\r]+")
    private val connectors = Regex("(?:然后|还有|接着|另外|再来|顺便|同时|之后|以及|最后)")
    private val softDelimiters = Regex("[，、]+")

    private val prefixes = listOf(
        "记得要", "要记得", "记得", "别忘了", "不要忘了", "别忘记", "提醒我", "帮我", "安排一下", "需要", "我得", "我要",
    )

    fun parse(raw: String, today: LocalDate = LocalDate.now()): List<TodoDraft> {
        val out = mutableListOf<TodoDraft>()
        for (segment in split(raw)) {
            val draft = analyze(segment, today) ?: continue
            if (out.any { it.title == draft.title && it.due == draft.due }) continue
            out.add(draft)
        }
        return out
    }

    // MARK: 切段

    fun split(raw: String): List<String> {
        val original = raw.trim()
        if (original.isEmpty()) return emptyList()

        val text = connectors.replace(original, "。")
        val pieces = mutableListOf<String>()

        for (hard in text.split(delimiters)) {
            val acc = mutableListOf<String>()
            for (soft in hard.split(softDelimiters)) {
                val s = clean(soft)
                if (s.isEmpty()) continue
                if (s.length <= 1 && !s.any { it.isDigit() } && acc.isNotEmpty()) {
                    acc[acc.size - 1] = acc.last() + s
                } else {
                    acc.add(s)
                }
            }
            if (acc.size > 1 && acc[0].length <= 1 && !acc[0].any { it.isDigit() }) {
                acc[1] = acc[0] + acc[1]
                acc.removeAt(0)
            }
            pieces.addAll(acc)
        }
        return pieces.filter { it.length >= 2 }
    }

    private fun clean(s: String): String = s.trim(' ', '，', '。', '！', '？', '；', '、', ',', '.', '!', '?', ';', ':', '：', '~', '～')

    // MARK: 单条

    private fun analyze(raw: String, today: LocalDate): TodoDraft? {
        var text = clean(raw)
        if (text.isEmpty()) return null

        for (p in prefixes) {
            if (text.startsWith(p)) {
                text = clean(text.substring(p.length))
                break
            }
        }
        if (text.isEmpty()) return null

        val (due, stripped) = extractDue(text, today)
        // 日期词被抠掉后可能留下空格 / 悬空的「的」
        var title = clean(stripped).replace(" ", "")
        while (title.startsWith("的")) title = title.drop(1)
        while (title.endsWith("的")) title = title.dropLast(1)
        // 只说了「明天」这种：标题退回原话
        if (title.length < 2) title = text
        if (title.length < 2 && title.none { it.isDigit() }) return null
        return TodoDraft(title = title, due = due)
    }

    // MARK: 日期

    fun extractDue(text: String, today: LocalDate): Pair<LocalDate?, String> {
        val base = today

        fun weekdayOf(target: Int, weeksAhead: Int): LocalDate {
            val monday = base.minusDays(((base.dayOfWeek.value - 1).toLong()))
            val offset = if (target == 1) 6 else target - 2
            var d = monday.plusDays((offset + weeksAhead * 7).toLong())
            if (weeksAhead == 0 && d.isBefore(base)) d = d.plusDays(7)
            return d
        }

        fun dateInMonth(offsetMonths: Long, dayOfMonth: Int): LocalDate =
            base.withDayOfMonth(1).plusMonths(offsetMonths).plusDays((dayOfMonth - 1).toLong())

        fun monthDay(month: Int, dayOfMonth: Int): LocalDate? {
            val first = LocalDate.of(base.year, month, 1).plusDays((dayOfMonth - 1).toLong())
            return if (first.isBefore(base)) LocalDate.of(base.year + 1, month, 1).plusDays((dayOfMonth - 1).toLong()) else first
        }

        fun cnWeekday(s: String): Int? = when (s) {
            "一", "1" -> 2
            "二", "2" -> 3
            "三", "3" -> 4
            "四", "4" -> 5
            "五", "5" -> 6
            "六", "6" -> 7
            "日", "天", "7" -> 1
            else -> null
        }

        data class Rule(val regex: Regex, val resolve: (MatchResult) -> LocalDate?)

        val rules = listOf(
            Rule(Regex("下下(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])")) { m ->
                cnWeekday(m.groupValues[1])?.let { weekdayOf(it, 2) }
            },
            Rule(Regex("下(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])")) { m ->
                cnWeekday(m.groupValues[1])?.let { weekdayOf(it, 1) }
            },
            Rule(Regex("(?:这|本)?(?:周|星期|礼拜)([一二三四五六日天1-7])")) { m ->
                cnWeekday(m.groupValues[1])?.let { weekdayOf(it, 0) }
            },
            Rule(Regex("(\\d{1,2})\\s*天(?:以)?后")) { m ->
                val n = m.groupValues[1].toIntOrNull() ?: 0
                if (n in 1..365) base.plusDays(n.toLong()) else null
            },
            Rule(Regex("下个?月(\\d{1,2})[号日]")) { m ->
                val d = m.groupValues[1].toIntOrNull()
                if (d != null && d in 1..31) dateInMonth(1, d) else null
            },
            Rule(Regex("(\\d{1,2})月(\\d{1,2})[号日]?")) { m ->
                val mo = m.groupValues[1].toIntOrNull()
                val d = m.groupValues[2].toIntOrNull()
                if (mo != null && d != null && mo in 1..12 && d in 1..31) monthDay(mo, d) else null
            },
            Rule(Regex("(\\d{1,2})[号日]")) { m ->
                val d = m.groupValues[1].toIntOrNull()
                if (d == null || d !in 1..31) {
                    null
                } else {
                    val thisMonth = dateInMonth(0, d)
                    if (!thisMonth.isBefore(base)) thisMonth else dateInMonth(1, d)
                }
            },
            Rule(Regex("大后天")) { _ -> base.plusDays(3) },
            Rule(Regex("后天")) { _ -> base.plusDays(2) },
            Rule(Regex("明天|明日|明早|明晚")) { _ -> base.plusDays(1) },
            Rule(Regex("今天|今日|今晚")) { _ -> base },
        )

        for (rule in rules) {
            val m = rule.regex.find(text) ?: continue
            val due = rule.resolve(m) ?: continue
            val rest = text.removeRange(m.range)
            return due to rest
        }
        return null to text
    }

    /** 供 UI 显示：今天 / 明天 / 10月8日 */
    fun dueText(due: LocalDate, today: LocalDate = LocalDate.now()): String {
        val days = java.time.temporal.ChronoUnit.DAYS.between(today, due)
        return when (days) {
            0L -> "今天"
            1L -> "明天"
            2L -> "后天"
            3L -> "大后天"
            else -> "${due.monthValue}月${due.dayOfMonth}日"
        }
    }
}
