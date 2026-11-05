package com.zsonit.mengbao.data

import com.zsonit.mengbao.model.AppSettings
import com.zsonit.mengbao.model.AppState
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.FeedLog
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.model.QuickEntry
import com.zsonit.mengbao.model.Sex
import com.zsonit.mengbao.model.ShotRecord
import com.zsonit.mengbao.model.SizeRecord
import com.zsonit.mengbao.model.TodoItem
import com.zsonit.mengbao.model.ToothDecay
import com.zsonit.mengbao.model.newId
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/**
 * 与 iOS 版本完全兼容的 JSON 备份格式。
 * Swift 的 JSONEncoder 默认把 Date 编成「距 2001-01-01 的秒数」，这里保持一致，
 * 因此 iOS 导出的备份可以直接在 Android 导入，反之亦然。
 */
object JsonCodec {

    private const val REFERENCE_EPOCH = 978307200L  // 2001-01-01T00:00:00Z

    // MARK: 日期

    private val zone: ZoneId get() = ZoneId.systemDefault()

    fun encodeDate(date: LocalDate): Double = encodeMoment(date.atStartOfDay())

    fun encodeMoment(dateTime: LocalDateTime): Double {
        val epoch = dateTime.atZone(zone).toEpochSecond()
        return (epoch - REFERENCE_EPOCH).toDouble()
    }

    fun decodeDate(value: Double?): LocalDate = decodeMoment(value)?.toLocalDate() ?: LocalDate.now()

    /** 还原成设备本地时间：iOS 存的是绝对时刻，按本地时区换算才不会跨天。 */
    fun decodeMoment(value: Double?): LocalDateTime? {
        if (value == null) return null
        val epoch = REFERENCE_EPOCH + value.toLong()
        return Instant.ofEpochSecond(epoch).atZone(zone).toLocalDateTime()
    }

    // MARK: 编码

    fun encode(state: AppState): String {
        val root = JSONObject()
        root.put("children", JSONArray().apply { state.children.forEach { put(encodeChild(it)) } })
        state.currentId?.let { root.put("currentID", it) }
        root.put("settings", encodeSettings(state.settings))
        if (state.tombstones.isNotEmpty()) {
            root.put("tombstones", JSONArray().apply { state.tombstones.forEach { put(it) } })
        }
        state.clearedAt?.let { root.put("clearedAt", it) }
        return root.toString(2)
    }

    private fun encodeChild(child: Child): JSONObject = JSONObject().apply {
        put("id", child.id)
        put("name", child.name)
        put("sex", child.sex.label)
        put("birthDate", encodeDate(child.birthDate))
        put("avatar", child.avatar)
        child.avatarPath?.let { put("avatarPath", it) }
        put("createdAt", encodeDate(child.createdAt))
        put("records", JSONArray().apply { child.records.forEach { put(encodeRecord(it)) } })
        put("feeds", JSONArray().apply { child.feeds.forEach { put(encodeFeed(it)) } })
        put("sizes", JSONArray().apply { child.sizes.forEach { put(encodeSize(it)) } })
        put("shots", JSONObject().apply {
            child.shots.forEach { (key, shot) ->
                put(key, JSONObject().apply {
                    put("date", encodeDate(shot.date))
                    put("note", shot.note)
                })
            }
        })
        child.teethFallen?.takeIf { it.isNotEmpty() }?.let { teeth ->
            // iOS 的 JSONEncoder 会把 [Int: Date] 编成「键值交替的数组」，这里保持同格式，双端互认
            put("teethFallen", JSONArray().apply { teeth.forEach { (code, d) -> put(code); put(encodeDate(d)) } })
        }
        child.teethDecay?.takeIf { it.isNotEmpty() }?.let { decay ->
            put("teethDecay", JSONArray().apply {
                decay.forEach { (code, d) ->
                    put(code)
                    put(JSONObject().apply {
                        put("date", encodeDate(d.date))
                        put("severity", d.severity)
                        put("note", d.note)
                    })
                }
            })
        }
        child.optVaccines?.takeIf { it.isNotEmpty() }?.let { ids ->
            put("optVaccines", JSONArray().apply { ids.forEach { put(it) } })
        }
        put("todos", JSONArray().apply { child.todos.forEach { put(encodeTodo(it)) } })
        child.updatedAt?.let { put("updatedAt", encodeMoment(it)) }
        child.birthdayRemind?.let { put("birthdayRemind", it) }
        child.birthdayTime?.let { put("birthdayTime", it) }
    }

    private fun encodeRecord(r: GrowthRecord): JSONObject = JSONObject().apply {
        put("id", r.id)
        put("date", encodeDate(r.date))
        r.height?.let { put("height", it) }
        r.weight?.let { put("weight", it) }
        r.footLength?.let { put("footLength", it) }
        r.headCirc?.let { put("headCirc", it) }
        put("note", r.note)
    }

    private fun encodeFeed(f: FeedLog): JSONObject = JSONObject().apply {
        put("id", f.id)
        put("date", encodeMoment(f.date.atTime(f.time ?: LocalTime.MIDNIGHT)))
        put("kind", f.kind.name.lowercase())
        f.minutes?.let { put("minutes", it) }
        f.ml?.let { put("ml", it) }
        f.side?.let { put("side", it) }
        f.diaperKind?.let { put("diaperKind", it) }
        f.value?.let { put("value", it) }
        f.tag?.let { put("tag", it) }
        put("note", f.note)
    }

    private fun encodeSize(s: SizeRecord): JSONObject = JSONObject().apply {
        put("id", s.id)
        put("date", encodeDate(s.date))
        s.footLength?.let { put("footLength", it) }
        s.height?.let { put("height", it) }
        s.shoulder?.let { put("shoulder", it) }
        s.waist?.let { put("waist", it) }
        s.hip?.let { put("hip", it) }
        s.thigh?.let { put("thigh", it) }
        s.calf?.let { put("calf", it) }
        s.legLength?.let { put("legLength", it) }
        s.armLength?.let { put("armLength", it) }
        s.topLength?.let { put("topLength", it) }
        s.sleeve?.let { put("sleeve", it) }
        s.pantsLength?.let { put("pantsLength", it) }
        s.shoeSize?.let { put("shoeSize", it) }
        s.shoeInner?.let { put("shoeInner", it) }
        put("note", s.note)
    }

    private fun encodeTodo(t: TodoItem): JSONObject = JSONObject().apply {
        put("id", t.id)
        put("title", t.title)
        t.due?.let { put("due", encodeDate(it)) }
        put("done", t.done)
    }

    private fun encodeSettings(s: AppSettings): JSONObject = JSONObject().apply {
        put("weightUnit", s.weightUnit)
        put("showFeed", s.showFeed)
        put("showShot", s.showShot)
        put("showSize", s.showSize)
        put("showTrends", s.showTrends)
        put("showLog", s.showLog)
        s.darkMode?.let { put("darkMode", it) }
        s.fatherHeight?.let { put("fatherHeight", it) }
        s.motherHeight?.let { put("motherHeight", it) }
        put("quickEntries", JSONArray().apply {
            s.quickEntries.forEach { q ->
                put(JSONObject().apply {
                    put("id", q.id)
                    put("kind", q.kind)
                    put("title", q.title)
                    put("icon", q.icon)
                    put("visible", q.visible)
                })
            }
        })
        // 提醒（本机通知）
        put("growthReminderOn", s.growthReminderOn)
        put("growthReminderDays", s.growthReminderDays)
        put("growthReminderHour", s.growthReminderHour)
        put("growthReminderMinute", s.growthReminderMinute)
        put("todoReminderOn", s.todoReminderOn)
        if (s.mutedTodoReminders.isNotEmpty()) {
            put("mutedTodoReminders", JSONArray().apply { s.mutedTodoReminders.forEach { put(it) } })
        }
    }

    // MARK: 解码

    fun decode(text: String): AppState {
        val root = JSONObject(text)
        val children = mutableListOf<Child>()
        val array = root.optJSONArray("children") ?: JSONArray()
        for (i in 0 until array.length()) {
            array.optJSONObject(i)?.let { children.add(decodeChild(it)) }
        }
        return AppState(
            children = children,
            currentId = root.optStringOrNull("currentID"),
            settings = root.optJSONObject("settings")?.let { decodeSettings(it) } ?: AppSettings(),
            tombstones = root.optJSONArray("tombstones")?.let { arr ->
                (0 until arr.length()).mapNotNull { arr.optString(it).ifEmpty { null } }.toSet()
            } ?: emptySet(),
            clearedAt = root.optStringOrNull("clearedAt"),
        )
    }

    private fun decodeChild(o: JSONObject): Child = Child(
        id = o.optString("id").ifEmpty { newId() },
        name = o.optString("name"),
        sex = Sex.of(o.optString("sex")),
        birthDate = decodeDate(o.optDoubleOrNull("birthDate")),
        avatar = o.optString("avatar"),
        avatarPath = if (o.has("avatarPath")) o.optString("avatarPath").ifEmpty { null } else null,
        createdAt = decodeDate(o.optDoubleOrNull("createdAt")),
        records = o.optJSONArray("records").objects().map { decodeRecord(it) },
        feeds = o.optJSONArray("feeds").objects().map { decodeFeed(it) },
        sizes = o.optJSONArray("sizes").objects().map { decodeSize(it) },
        shots = o.optJSONObject("shots").let { shots ->
            val map = mutableMapOf<String, ShotRecord>()
            shots?.keys()?.forEach { key ->
                shots.optJSONObject(key)?.let { map[key] = ShotRecord(decodeDate(it.optDoubleOrNull("date")), it.optString("note")) }
            }
            map
        },
        todos = o.optJSONArray("todos").objects().map { decodeTodo(it) },
        teethFallen = decodeIntKeyedDates(o.optJSONArray("teethFallen"), o.optJSONObject("teethFallen")),
        teethDecay = decodeTeethDecay(o),
        optVaccines = o.optJSONArray("optVaccines")?.let { arr ->
            (0 until arr.length()).mapNotNull { arr.optString(it).ifEmpty { null } }.ifEmpty { null }
        },
        updatedAt = o.optDoubleOrNull("updatedAt")?.let { decodeMoment(it) },
        birthdayRemind = o.optBooleanOrNull("birthdayRemind"),
        birthdayTime = o.optIntOrNull("birthdayTime"),
    )

    private fun decodeRecord(o: JSONObject) = GrowthRecord(
        id = o.optString("id").ifEmpty { newId() },
        date = decodeDate(o.optDoubleOrNull("date")),
        height = o.optDoubleOrNull("height"),
        weight = o.optDoubleOrNull("weight"),
        footLength = o.optDoubleOrNull("footLength"),
        headCirc = o.optDoubleOrNull("headCirc"),
        note = o.optString("note"),
    )

    private fun decodeFeed(o: JSONObject): FeedLog {
        val moment = decodeMoment(o.optDoubleOrNull("date"))
        return FeedLog(
            id = o.optString("id").ifEmpty { newId() },
            date = moment?.toLocalDate() ?: LocalDate.now(),
            time = moment?.toLocalTime(),
            kind = FeedLog.Kind.of(o.optString("kind")),
            minutes = o.optIntOrNull("minutes"),
            ml = o.optDoubleOrNull("ml"),
            side = o.optStringOrNull("side"),
            diaperKind = o.optStringOrNull("diaperKind"),
            value = o.optDoubleOrNull("value"),
            tag = o.optStringOrNull("tag"),
            note = o.optString("note"),
        )
    }

    private fun decodeSize(o: JSONObject) = SizeRecord(
        id = o.optString("id").ifEmpty { newId() },
        date = decodeDate(o.optDoubleOrNull("date")),
        footLength = o.optDoubleOrNull("footLength"),
        height = o.optDoubleOrNull("height"),
        shoulder = o.optDoubleOrNull("shoulder"),
        waist = o.optDoubleOrNull("waist"),
        hip = o.optDoubleOrNull("hip"),
        thigh = o.optDoubleOrNull("thigh"),
        calf = o.optDoubleOrNull("calf"),
        legLength = o.optDoubleOrNull("legLength"),
        armLength = o.optDoubleOrNull("armLength"),
        topLength = o.optDoubleOrNull("topLength"),
        sleeve = o.optDoubleOrNull("sleeve"),
        pantsLength = o.optDoubleOrNull("pantsLength"),
        shoeSize = o.optIntOrNull("shoeSize"),
        shoeInner = o.optDoubleOrNull("shoeInner"),
        note = o.optString("note"),
    )

    private fun decodeTodo(o: JSONObject) = TodoItem(
        id = o.optString("id").ifEmpty { newId() },
        title = o.optString("title"),
        due = o.optDoubleOrNull("due")?.let { decodeDate(it) },
        done = o.optBoolean("done", false),
    )

    private fun decodeSettings(o: JSONObject) = AppSettings(
        weightUnit = o.optString("weightUnit", "kg").ifEmpty { "kg" },
        showFeed = o.optBoolean("showFeed", true),
        showShot = o.optBoolean("showShot", true),
        showSize = o.optBoolean("showSize", true),
        showTrends = o.optBoolean("showTrends", true),
        showLog = o.optBoolean("showLog", false),
        darkMode = if (o.has("darkMode") && !o.isNull("darkMode")) o.optBoolean("darkMode") else null,
        fatherHeight = o.optDoubleOrNull("fatherHeight"),
        motherHeight = o.optDoubleOrNull("motherHeight"),
        quickEntries = o.optJSONArray("quickEntries").objects().map { q ->
            QuickEntry(
                id = q.optString("id"),
                kind = q.optString("kind"),
                title = q.optString("title"),
                icon = q.optString("icon"),
                visible = q.optBoolean("visible", true),
            )
        }.filter { it.id.isNotEmpty() },
        growthReminderOn = o.optBoolean("growthReminderOn", false),
        growthReminderDays = o.optIntOrNull("growthReminderDays") ?: 30,
        growthReminderHour = o.optIntOrNull("growthReminderHour") ?: 9,
        growthReminderMinute = o.optIntOrNull("growthReminderMinute") ?: 0,
        todoReminderOn = o.optBoolean("todoReminderOn", true),
        mutedTodoReminders = o.optJSONArray("mutedTodoReminders")?.let { arr ->
            (0 until arr.length()).mapNotNull { arr.optString(it).ifEmpty { null } }.toSet()
        } ?: emptySet(),
    )
}

// MARK: - JSON 小工具

/** [Int: LocalDate]：兼容两种格式——Swift 的「键值交替数组」和安卓老版本的 {"51": date} 对象 */
private fun decodeIntKeyedDates(arr: JSONArray?, obj: JSONObject?): Map<Int, LocalDate>? {
    val out = mutableMapOf<Int, LocalDate>()
    if (obj != null) {
        obj.keys()?.forEach { key ->
            key.toIntOrNull()?.let { code -> out[code] = JsonCodec.decodeDate(obj.optDoubleOrNull(key)) }
        }
    } else if (arr != null) {
        var i = 0
        while (i + 1 < arr.length()) {
            val code = arr.optInt(i, Int.MIN_VALUE)
            if (code != Int.MIN_VALUE) out[code] = JsonCodec.decodeDate(arr.optDoubleOrNull(i + 1))
            i += 2
        }
    }
    return out.ifEmpty { null }
}

/** [Int: ToothDecay]：同样兼容「键值交替数组」（iOS）与对象（安卓老备份） */
private fun decodeTeethDecay(o: JSONObject): Map<Int, ToothDecay>? {
    val out = mutableMapOf<Int, ToothDecay>()
    fun put(code: Int, d: JSONObject?) {
        if (code == Int.MIN_VALUE || d == null) return
        out[code] = ToothDecay(
            date = JsonCodec.decodeDate(d.optDoubleOrNull("date")),
            severity = d.optIntOrNull("severity") ?: 1,
            note = d.optString("note"),
        )
    }
    val arr = o.optJSONArray("teethDecay")
    if (arr != null) {
        var i = 0
        while (i + 1 < arr.length()) {
            put(arr.optInt(i, Int.MIN_VALUE), arr.optJSONObject(i + 1))
            i += 2
        }
    } else {
        o.optJSONObject("teethDecay")?.let { jo ->
            jo.keys()?.forEach { key -> put(key.toIntOrNull() ?: Int.MIN_VALUE, jo.optJSONObject(key)) }
        }
    }
    return out.ifEmpty { null }
}

private fun JSONArray.objects(): List<JSONObject> =
    (0 until length()).mapNotNull { optJSONObject(it) }

private fun JSONObject.optStringOrNull(key: String): String? =
    if (has(key) && !isNull(key)) optString(key) else null

private fun JSONObject.optDoubleOrNull(key: String): Double? =
    if (has(key) && !isNull(key)) optDouble(key) else null

private fun JSONArray.optDoubleOrNull(index: Int): Double? =
    if (index in 0 until length() && !isNull(index)) optDouble(index) else null

private fun JSONObject.optIntOrNull(key: String): Int? =
    if (has(key) && !isNull(key)) optInt(key) else null

private fun JSONObject.optBooleanOrNull(key: String): Boolean? =
    if (has(key) && !isNull(key)) optBoolean(key) else null
