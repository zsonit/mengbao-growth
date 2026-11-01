package com.zsonit.mengbao.data

import com.zsonit.mengbao.model.FeedLog

/**
 * 语音/文字 → 记录（纯本地规则，不联网、不上传）。
 * 与 iOS `VoiceParser.swift` 规则逐条一致。
 */
data class VoiceParseResult(
    val kind: String? = null,        // bottle/breast/pumping/sleep/diaper/solid/supplement/temp/custom/growth
    val entryId: String? = null,     // 命中的快捷入口 id
    val value: Double? = null,       // 体温 / 生长数值
    val minutes: Int? = null,
    val ml: Double? = null,
    val side: String? = null,
    val diaperKind: String? = null,
    val note: String = "",
    val text: String = "",
) {
    val ok: Boolean get() = kind != null

    val summary: String
        get() = when (kind) {
            null -> "没听懂"
            "bottle" -> "瓶喂 ${(ml ?: 0.0).toInt()} ml"
            "pumping" -> "吸奶 ${(ml ?: 0.0).toInt()} ml"
            "breast" -> "亲喂 ${side ?: "左"}侧${minutes?.let { " $it 分钟" } ?: ""}"
            "sleep" -> "睡眠 ${minutes ?: 0} 分钟"
            "diaper" -> "尿布 · ${diaperKind ?: "小便"}"
            "solid" -> if (note.isEmpty()) "辅食" else "辅食 · $note"
            "supplement" -> if (note.isEmpty()) "补剂" else "补剂 · $note"
            "temp" -> String.format("体温 %.1f ℃", value ?: 36.5)
            "growth" -> when (entryId) {
                "height" -> String.format("身高 %.1f cm", value ?: 0.0)
                "weight" -> String.format("体重 %.1f kg", value ?: 0.0)
                "head" -> String.format("头围 %.1f cm", value ?: 0.0)
                else -> "生长记录"
            }
            else -> if (note.isEmpty()) "记录" else note
        }

    /** 转成一条 FeedLog（growth 类型返回 null，由调用方写 GrowthRecord） */
    fun toFeedLog(date: java.time.LocalDate = java.time.LocalDate.now(), time: java.time.LocalTime = java.time.LocalTime.now().withSecond(0).withNano(0)): FeedLog? {
        val k = when (kind) {
            "bottle" -> FeedLog.Kind.BOTTLE
            "breast" -> FeedLog.Kind.BREAST
            "pumping" -> FeedLog.Kind.PUMPING
            "sleep" -> FeedLog.Kind.SLEEP
            "diaper" -> FeedLog.Kind.DIAPER
            "solid" -> FeedLog.Kind.SOLID
            "supplement" -> FeedLog.Kind.SUPPLEMENT
            "temp" -> FeedLog.Kind.TEMP
            "custom" -> FeedLog.Kind.CUSTOM
            else -> return null
        }
        return FeedLog(
            date = date,
            time = time,
            kind = k,
            minutes = minutes,
            ml = ml,
            side = side,
            diaperKind = diaperKind,
            value = value,
            note = note,
        )
    }
}

object VoiceParser {

    private val cnDigits = mapOf(
        '零' to 0, '〇' to 0, '一' to 1, '二' to 2, '两' to 2, '三' to 3, '四' to 4,
        '五' to 5, '六' to 6, '七' to 7, '八' to 8, '九' to 9,
    )

    /** 把中文数字换成阿拉伯数字：「二十三」→「23」 */
    fun normalizeNumbers(input: String): String {
        var text = input
        // 「两个半小时」这类要先整体换算，否则会被「半小时→30分钟」的替换拆坏
        text = Regex("([0-9]+|[零〇一二两三四五六七八九十]+)\\s*个?\\s*半\\s*(?:小时|钟头)")
            .replace(text) { m -> "${cnNumberToInt(m.groupValues[1]) * 60 + 30}分钟" }
        text = text.replace("一个半小时", "90分钟")
        text = text.replace("半个小时", "30分钟")
        text = text.replace("半小时", "30分钟")
        text = text.replace("一个钟", "60分钟")
        text = text.replace("一刻钟", "15分钟")

        val sb = StringBuilder()
        val cur = StringBuilder()
        var acc = 0

        fun flush() {
            if (cur.isNotEmpty()) {
                sb.append(acc)
                cur.clear()
                acc = 0
            }
        }

        for (ch in text) {
            val d = cnDigits[ch]
            when {
                d != null -> { acc = acc * 10 + d; cur.append(ch) }
                ch == '十' -> { acc = (if (acc == 0) 1 else acc) * 10; cur.append(ch) }
                ch == '百' -> { acc = (if (acc == 0) 1 else acc) * 100; cur.append(ch) }
                ch == '半' && cur.isNotEmpty() -> { flush(); sb.append(".5") }
                else -> { flush(); sb.append(ch) }
            }
        }
        flush()
        return sb.toString()
    }

    private fun cnNumberToInt(s: String): Int {
        var acc = 0
        var total = 0
        for (ch in s) {
            val d = cnDigits[ch]
            when {
                d != null -> acc = acc * 10 + d
                ch == '十' -> { total += (if (acc == 0) 1 else acc) * 10; acc = 0 }
                ch == '百' -> { total += (if (acc == 0) 1 else acc) * 100; acc = 0 }
            }
        }
        return total + acc
    }

    private fun numbers(text: String): List<Double> =
        Regex("""(\d+(?:\.\d+)?)""").findAll(text).mapNotNull { it.groupValues[1].toDoubleOrNull() }.toList()

    private fun firstNumber(text: String, range: ClosedFloatingPointRange<Double>): Double? =
        numbers(text).firstOrNull { it in range }

    private fun firstMatch(text: String, pattern: String): String? {
        val m = Regex(pattern).find(text) ?: return null
        return if (m.groupValues.size > 1) m.groupValues[1] else m.value
    }

    /** 时长（分钟）：支持「2小时」「1小时20分钟」「40分钟」 */
    private fun duration(text: String): Int? {
        var total: Int? = null
        firstMatch(text, """(\d+(?:\.\d+)?)\s*(?:个)?\s*小时""")?.toDoubleOrNull()?.let { total = (it * 60).toInt() }
        firstMatch(text, """(\d+)\s*分钟""")?.toIntOrNull()?.let { total = (total ?: 0) + it }
        return total
    }

    private fun containsAny(text: String, keys: List<String>) = keys.any { text.contains(it) }

    fun parse(raw: String): VoiceParseResult {
        val original = raw.trim()
        val text = normalizeNumbers(original)

        // 1) 体温
        if (containsAny(text, listOf("体温", "发烧", "发热", "烧到", "度"))) {
            firstNumber(text, 34.0..43.0)?.let {
                return VoiceParseResult(kind = "temp", entryId = "temp", value = it, text = original)
            }
        }
        // 2) 身高 / 体重 / 头围
        if (containsAny(text, listOf("身高", "身长", "长高"))) {
            firstNumber(text, 30.0..200.0)?.let {
                return VoiceParseResult(kind = "growth", entryId = "height", value = it, text = original)
            }
        }
        if (containsAny(text, listOf("体重", "重了", "称了"))) {
            firstNumber(text, 1.0..120.0)?.let {
                return VoiceParseResult(kind = "growth", entryId = "weight", value = it, text = original)
            }
        }
        if (containsAny(text, listOf("头围"))) {
            firstNumber(text, 20.0..70.0)?.let {
                return VoiceParseResult(kind = "growth", entryId = "head", value = it, text = original)
            }
        }
        // 3) 吸奶
        if (containsAny(text, listOf("吸奶", "泵奶", "挤奶", "吸出来"))) {
            return VoiceParseResult(
                kind = "pumping", entryId = "pumping",
                ml = firstNumber(text, 5.0..500.0), text = original,
            )
        }
        // 4) 亲喂
        if (containsAny(text, listOf("亲喂", "母乳", "吃奶", "喂了奶")) &&
            !containsAny(text, listOf("奶瓶", "奶粉"))
        ) {
            if (containsAny(text, listOf("左", "右"))) {
                return VoiceParseResult(
                    kind = "breast", entryId = "breast",
                    side = if (text.contains("右")) "右" else "左",
                    minutes = duration(text), text = original,
                )
            }
            duration(text)?.let {
                if (it > 0) return VoiceParseResult(
                    kind = "breast", entryId = "breast", side = "左", minutes = it, text = original,
                )
            }
        }
        // 5) 瓶喂
        if (containsAny(text, listOf("奶", "毫升", "ml", "ML"))) {
            val ml = firstNumber(text, 10.0..500.0)
            if (ml != null) {
                return VoiceParseResult(kind = "bottle", entryId = "bottle", ml = ml, text = original)
            }
            if (containsAny(text, listOf("喂了", "喝了", "喝奶", "吃了奶", "奶粉", "奶瓶"))) {
                return VoiceParseResult(
                    kind = "bottle", entryId = "bottle", ml = 120.0,
                    note = "未说毫升数，按 120ml 记", text = original,
                )
            }
        }
        // 6) 睡眠
        if (containsAny(text, listOf("睡", "午觉", "小睡", "眯了"))) {
            return VoiceParseResult(
                kind = "sleep", entryId = "sleep",
                minutes = duration(text) ?: 60, text = original,
            )
        }
        // 7) 尿布
        if (containsAny(text, listOf("尿布", "尿不湿", "换尿", "尿了", "拉了", "臭臭", "便便", "大便", "小便"))) {
            return VoiceParseResult(
                kind = "diaper", entryId = "diaper",
                diaperKind = if (containsAny(text, listOf("大便", "臭臭", "便便", "拉了"))) "大便" else "小便",
                text = original,
            )
        }
        // 8) 辅食
        if (containsAny(
                text,
                listOf("辅食", "吃了", "米粉", "粥", "面条", "果泥", "菜泥", "肉泥", "蛋黄", "鸡蛋", "水果", "香蕉", "苹果"),
            )
        ) {
            return VoiceParseResult(kind = "solid", entryId = "solid", note = foodWords(text), text = original)
        }
        // 9) 补剂
        if (containsAny(
                text,
                listOf("维生素", "维D", "D3", "AD", "钙", "铁剂", "补铁", "锌", "DHA", "益生菌", "补剂"),
            )
        ) {
            return VoiceParseResult(kind = "supplement", entryId = "supplement", note = supplementWords(text), text = original)
        }
        // 10) 兜底
        return if (original.isEmpty()) VoiceParseResult(text = original)
        else VoiceParseResult(kind = "custom", note = original, text = original)
    }

    private fun foodWords(text: String): String {
        val keywords = listOf(
            "米粉", "粥", "面条", "烂面", "果泥", "菜泥", "肉泥", "蛋黄", "鸡蛋",
            "香蕉", "苹果", "南瓜", "土豆", "牛油果", "西兰花", "胡萝卜", "虾", "鱼", "肝粉", "豆腐", "酸奶",
        )
        val hit = keywords.filter { text.contains(it) }
        if (hit.isNotEmpty()) return hit.joinToString("、")
        val idx = text.indexOf("吃了")
        if (idx >= 0) return text.substring(idx + 2).trim()
        return ""
    }

    private fun supplementWords(text: String): String {
        val keywords = listOf("维生素D3", "维生素D", "维D", "D3", "AD滴剂", "AD", "钙剂", "钙", "铁剂", "补铁", "锌", "DHA", "益生菌")
        return keywords.firstOrNull { text.contains(it) } ?: "补剂"
    }

    // MARK: - 长语音：整段话拆成多条记录

    /** 句子分隔符（不含「、」，避免拆散「米粉、蛋黄」这类食物列举） */
    private val sentenceDelim = Regex("[，。！？；,!?;\\n\\r]+")

    /** 口头连接词，当作句子分隔 */
    private val connectors = Regex("(?:然后|还有|接着|另外|再来|以及|同时|其次|后面|之后)")

    /**
     * 动词型起点关键词：每个出现位置都是一条记录的开始。
     * 语音识别出的文本通常没有标点（「喝了150毫升奶换了尿布睡了40分钟」），
     * 只靠标点拆不开，必须按动词起点切。
     */
    private val verbStarts = listOf(
        "体温", "发烧", "发热", "烧到", "身高", "身长", "长高", "体重", "称了", "称重", "头围",
        "亲喂", "吸奶", "泵奶", "挤奶", "吸出来", "喂奶", "喂了", "喝", "吃", "睡", "午觉", "小睡", "眯了",
        "尿", "拉了", "臭臭", "便便", "大便", "小便", "换尿",
        "辅食", "米粉", "果泥", "菜泥", "肉泥", "蛋黄", "鸡蛋", "香蕉", "苹果", "粥", "面条",
        "维生素", "维D", "D3", "钙", "铁剂", "补铁", "锌", "DHA", "益生菌", "补剂",
    )

    private fun trimEdge(s: String): String =
        s.trim('，', '。', '！', '？', '；', ',', '!', '?', ';', ' ', '\n', '\r')

    /**
     * 把一大段话拆成一句一条：
     * 1) 连接词（然后/还有…）替换成逗号；
     * 2) 标点 + 动词起点共同作为切割点；
     * 3) 过短的口癖碎段（≤2字且无数字，如「我在」「啊」）并入相邻段。
     */
    fun splitSegments(raw: String): List<String> {
        val original = raw.trim()
        if (original.isEmpty()) return emptyList()
        val text = connectors.replace(original, "，")

        val cuts = sortedSetOf<Int>()
        sentenceDelim.findAll(text).forEach { cuts.add(it.range.first) }
        for (kw in verbStarts) {
            var idx = text.indexOf(kw)
            while (idx >= 0) {
                cuts.add(idx)
                idx = text.indexOf(kw, idx + 1)
            }
        }
        if (cuts.isEmpty()) return listOf(trimEdge(text))

        val bounds = (setOf(0) + cuts.filter { it in text.indices }).sorted()
        val segs = mutableListOf<String>()
        for (i in bounds.indices) {
            val start = bounds[i]
            val end = if (i + 1 < bounds.size) bounds[i + 1] else text.length
            val s = trimEdge(text.substring(start, end))
            if (s.isEmpty()) continue
            // 碎段（口癖/主语）并入前段
            if (s.length <= 2 && s.none { it.isDigit() } && segs.isNotEmpty()) {
                segs[segs.size - 1] = segs.last() + s
            } else {
                segs.add(s)
            }
        }
        // 开头就只剩一个碎段时并入下一段
        if (segs.size > 1 && segs[0].length <= 2 && segs[0].none { it.isDigit() }) {
            segs[1] = segs[0] + segs[1]
            segs.removeAt(0)
        }
        return segs
    }

    /**
     * 长语音解析：逐句 parse，能归类的进 results（同类说几遍就记几条），
     * 归类不了的进 unknown（在确认页提示用户，不乱记）。
     */
    fun parseAll(raw: String): Pair<List<VoiceParseResult>, List<String>> {
        val segments = splitSegments(raw)
        if (segments.isEmpty()) return emptyList<VoiceParseResult>() to emptyList()
        val results = mutableListOf<VoiceParseResult>()
        val unknown = mutableListOf<String>()
        for (seg in segments) {
            val r = parse(seg)
            if (r.kind == null || r.kind == "custom") {
                unknown.add(seg)
                continue
            }
            // 被切碎的纯动词短语（如「米粉和蛋黄都 / 吃了」）：与上一条同类型且没有实质内容，跳过
            if ((r.kind == "solid" || r.kind == "supplement") && r.note.isEmpty() &&
                results.lastOrNull()?.kind == r.kind
            ) continue
            results.add(r)
        }
        return results to unknown
    }
}

/** 弹层里的快捷 chips */
object EntryPresets {
    val foods = listOf("米粉", "土豆泥", "南瓜泥", "牛油果泥", "肉泥", "蛋黄", "苹果泥", "香蕉泥")
    val supplements = listOf("维生素D3", "AD滴剂", "钙剂", "铁剂", "DHA", "益生菌")
    val diaperKinds = listOf("小便", "大便", "混合")
    val milkAmounts = listOf(60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0)
    val sleepMinutes = listOf(15, 30, 45, 60, 90, 120)
}
