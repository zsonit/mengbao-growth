package com.zsonit.mengbao.model

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.util.UUID

fun newId(): String = UUID.randomUUID().toString().uppercase()

// MARK: - 性别

enum class Sex(val label: String) {
    BOY("男"),
    GIRL("女");

    // 默认头像换成可爱、现代风格的小动物
    val symbol: String get() = if (this == BOY) "🐣" else "🐰"

    companion object {
        fun of(value: String?): Sex = if (value == "女") GIRL else BOY
    }
}

// MARK: - 生长记录

data class GrowthRecord(
    val id: String = newId(),
    val date: LocalDate,
    val height: Double? = null,
    val weight: Double? = null,
    val footLength: Double? = null,
    val headCirc: Double? = null,
    val note: String = "",
) {
    val hasAnyValue: Boolean
        get() = height != null || weight != null || footLength != null || headCirc != null
}

// MARK: - 喂养记录

data class FeedLog(
    val id: String = newId(),
    val date: LocalDate,
    val time: LocalTime? = null,
    val kind: Kind,
    val minutes: Int? = null,
    val ml: Double? = null,
    val side: String? = null,
    val diaperKind: String? = null,
    /** 通用数值位：体温（℃）、辅食克数、喂药剂量（ml）等 */
    val value: Double? = null,
    /** 通用标签位：瓶喂（奶粉/人奶）、储奶（冷藏/冷冻）、喂药/记事本（发烧/感冒…） */
    val tag: String? = null,
    val note: String = "",
) {
    enum class Kind(val title: String, val icon: String, val unit: String) {
        SLEEP("睡眠", "😴", "分钟"),
        BREAST("亲喂", "🤱", "分钟"),
        BOTTLE("瓶喂", "🍼", "ml"),
        PUMPING("吸奶", "🧴", "ml"),
        STORAGE("储奶", "🥛", "ml"),
        DIAPER("尿布", "🧷", "次"),
        SOLID("辅食", "🍚", ""),
        SUPPLEMENT("补剂", "💊", ""),
        MEDICINE("喂药", "🩺", "ml"),
        TEMP("体温", "🌡️", "℃"),
        NOTEBOOK("记事本", "📒", ""),
        CUSTOM("记录", "📝", "");

        val isFeedLike: Boolean
            get() = this == BOTTLE || this == BREAST || this == PUMPING ||
                this == SOLID || this == SLEEP || this == DIAPER

        companion object {
            fun of(value: String?): Kind =
                entries.firstOrNull { it.name.equals(value, true) } ?: SLEEP

            /** JSON 里用小驼峰存（与 iOS rawValue 一致） */
            fun key(kind: Kind): String = kind.name.lowercase()
        }
    }

    val summary: String
        get() = when (kind) {
            Kind.SLEEP -> "${minutes ?: 0} 分钟"
            Kind.BREAST -> "${side ?: "左"} ${minutes?.let { "$it 分钟" } ?: ""}".trim()
            Kind.BOTTLE -> "${(ml ?: 0.0).toInt()} ml" + (tag?.let { " · $it" } ?: "")
            Kind.PUMPING -> "${(ml ?: 0.0).toInt()} ml"
            Kind.STORAGE -> "${(ml ?: 0.0).toInt()} ml" + (tag?.let { " · $it" } ?: "")
            Kind.DIAPER -> diaperKind ?: "小便"
            Kind.SOLID -> note.ifEmpty { "已添加辅食" }
            Kind.SUPPLEMENT -> note.ifEmpty { "已服用" }
            Kind.MEDICINE -> {
                val dose = if ((value ?: 0.0) > 0) String.format("%.1f ml", value ?: 0.0) else ""
                val name = note.ifEmpty { "喂药" }
                (if (dose.isEmpty()) name else "$name $dose") + (tag?.let { " · $it" } ?: "")
            }
            Kind.TEMP -> String.format("%.1f ℃", value ?: 36.5)
            Kind.NOTEBOOK -> note.ifEmpty { "记事本" }
            Kind.CUSTOM -> note.ifEmpty { "记录" }
        }

    /** 语音/一键录入时给 AI 卡用的自然语言摘要 */
    val speakText: String
        get() = when (kind) {
            Kind.SLEEP -> "睡了 ${minutes ?: 0} 分钟"
            Kind.BREAST -> "亲喂 ${side ?: "左"} 侧 ${minutes ?: 0} 分钟"
            Kind.BOTTLE -> "喝了 ${(ml ?: 0.0).toInt()} 毫升${tag ?: "奶"}"
            Kind.PUMPING -> "吸奶 ${(ml ?: 0.0).toInt()} 毫升"
            Kind.STORAGE -> "储奶 ${(ml ?: 0.0).toInt()} 毫升" + (tag?.let { "（$it）" } ?: "")
            Kind.DIAPER -> diaperKind ?: "小便"
            Kind.SOLID -> "吃了 $note"
            Kind.SUPPLEMENT -> "补了 $note"
            Kind.MEDICINE -> {
                val dose = if ((value ?: 0.0) > 0) String.format("%.1f 毫升", value ?: 0.0) else ""
                "喂了 $note" + (if (dose.isEmpty()) "" else " $dose") + (tag?.let { "（$it）" } ?: "")
            }
            Kind.TEMP -> String.format("体温 %.1f 度", value ?: 36.5)
            Kind.NOTEBOOK -> "记录：$note"
            Kind.CUSTOM -> note
        }
}

// MARK: - 鞋服尺码

data class SizeRecord(
    val id: String = newId(),
    val date: LocalDate,
    val footLength: Double? = null,
    val height: Double? = null,
    // 身体围度 / 衣物尺寸（cm）
    val shoulder: Double? = null,
    val waist: Double? = null,
    val hip: Double? = null,
    val thigh: Double? = null,
    val calf: Double? = null,
    val legLength: Double? = null,
    val armLength: Double? = null,
    val topLength: Double? = null,
    val sleeve: Double? = null,
    val pantsLength: Double? = null,
    val shoeSize: Int? = null,
    val shoeInner: Double? = null,
    val note: String = "",
) {
    /** 填了几项（含备注）：用来挑「最完整」的那条，也是去重时的优先级 */
    val filledCount: Int
        get() = listOf(
            footLength, height, shoulder, waist, hip, thigh, calf,
            legLength, armLength, topLength, sleeve, pantsLength, shoeInner, shoeSize?.toDouble(),
        ).count { it != null } + if (note.isNotBlank()) 1 else 0

    /** 全是空的记录（历史脏数据），展示和同步时都过滤掉 */
    val hasContent: Boolean get() = filledCount > 0

    /** 同一天归并用的键（同步时同一天只保留一条去重记录） */
    val dayKey: String get() = date.toString()

    /** 用旧记录补上新记录里没填的项（同一天再保存时，不会把上次填的围度弄丢） */
    fun fillMissingFrom(old: SizeRecord): SizeRecord = copy(
        footLength = footLength ?: old.footLength,
        height = height ?: old.height,
        shoulder = shoulder ?: old.shoulder,
        waist = waist ?: old.waist,
        hip = hip ?: old.hip,
        thigh = thigh ?: old.thigh,
        calf = calf ?: old.calf,
        legLength = legLength ?: old.legLength,
        armLength = armLength ?: old.armLength,
        topLength = topLength ?: old.topLength,
        sleeve = sleeve ?: old.sleeve,
        pantsLength = pantsLength ?: old.pantsLength,
        shoeSize = shoeSize ?: old.shoeSize,
        shoeInner = shoeInner ?: old.shoeInner,
        note = note.ifBlank { old.note },
    )
}

// MARK: - 待办

data class TodoItem(
    val id: String = newId(),
    val title: String,
    val due: LocalDate? = null,
    val done: Boolean = false,
)

// MARK: - 接种记录

data class ShotRecord(
    val date: LocalDate,
    val note: String = "",
)

// MARK: - 龋齿（换牙档案）

/** 一颗乳牙的龋齿（烂牙）记录，与 iOS ToothDecay 保持一致 */
data class ToothDecay(
    val date: LocalDate,          // 发现 / 就诊日期
    val severity: Int = 1,        // 1=轻度（白斑、浅龋）2=中度（有洞）3=重度（深龋、疼过、需治疗）
    val note: String = "",        // 备注：哪一面、医生说了什么、是否已补
) {
    val severityLabel: String
        get() = when (severity) {
            3 -> "重度"
            2 -> "中度"
            else -> "轻度"
        }

    /** 中重度建议尽快看牙医 */
    val needsVisit: Boolean get() = severity >= 2
}

// MARK: - 宝宝

data class Child(
    val id: String = newId(),
    val name: String,
    val sex: Sex,
    val birthDate: LocalDate,
    val avatar: String = "",
    val avatarPath: String? = null,   // 自定义照片（相对 filesDir 的文件名，如 avatars/<id>.jpg）
    val createdAt: LocalDate = LocalDate.now(),
    val records: List<GrowthRecord> = emptyList(),
    val feeds: List<FeedLog> = emptyList(),
    val sizes: List<SizeRecord> = emptyList(),
    val shots: Map<String, ShotRecord> = emptyMap(),
    val todos: List<TodoItem> = emptyList(),
    val teethFallen: Map<Int, LocalDate>? = null,  // 换牙档案：乳牙 FDI 编码 -> 脱落日期
    val teethDecay: Map<Int, ToothDecay>? = null,  // 换牙档案：乳牙 FDI 编码 -> 龋齿（烂牙）记录
    val optVaccines: List<String>? = null,         // 自选（自费）疫苗 id，见 Standards.optionalCatalog
    val updatedAt: LocalDateTime? = null,          // 配对同步：档案最后一次修改时刻（冲突时后改的赢）
    val birthdayRemind: Boolean? = null,           // 旧字段：生日提醒总开关（兼容旧版本数据，null = 开）
    val birthdayTime: Int? = null,                 // 旧字段：生日提醒时刻（0-1439 分钟，null = 9:00）
    // v2.10.22：生日提醒拆分为「当天」和「提前」两个独立开关，时间各自可调
    val bdaySameDayOn: Boolean? = null,            // 当天提醒开关（null = 跟随旧字段，默认开）
    val bdaySameDayTime: Int? = null,              // 当天提醒时刻（分钟，null = 跟随 birthdayTime / 9:00）
    val bdayAdvanceOn: Boolean? = null,            // 提前提醒开关（null = 跟随旧字段，默认开）
    val bdayAdvanceDays: Int? = null,              // 提前几天（默认 1）
    val bdayAdvanceTime: Int? = null,              // 提前提醒时刻（分钟，null = 跟随 birthdayTime / 9:00）
) {
    val displayAvatar: String
        get() = if (avatar.isEmpty()) (if (sex == Sex.GIRL) "👧" else "👦") else avatar

    /** 当天提醒是否开启（兼容旧数据：未拆分时跟随总开关） */
    val bdaySameDayEnabled: Boolean get() = bdaySameDayOn ?: birthdayRemind ?: true
    /** 提前提醒是否开启 */
    val bdayAdvanceEnabled: Boolean get() = bdayAdvanceOn ?: birthdayRemind ?: true
    /** 当天提醒时刻（分钟） */
    val bdaySameDayMinutes: Int get() = bdaySameDayTime ?: birthdayTime ?: 9 * 60
    /** 提前提醒时刻（分钟） */
    val bdayAdvanceMinutes: Int get() = bdayAdvanceTime ?: birthdayTime ?: 9 * 60
    /** 提前几天（至少 1 天） */
    val bdayAdvanceDaysEffective: Int get() = maxOf(1, bdayAdvanceDays ?: 1)

    val sortedRecords: List<GrowthRecord>
        get() = records.sortedBy { it.date }

    val latestRecord: GrowthRecord?
        get() = records.maxByOrNull { it.date }

    val latestHeight: Double?
        get() = sortedRecords.lastOrNull { it.height != null }?.height

    val latestWeight: Double?
        get() = sortedRecords.lastOrNull { it.weight != null }?.weight
}

// MARK: - 快捷入口配置

data class QuickEntry(
    val id: String,                                   // 内置项用 kind 值，自定义项用 "custom-<UUID>"
    val kind: String,                                 // bottle/breast/... 或 height/weight/head/custom
    val title: String,
    val icon: String,
    val visible: Boolean = true,
) {
    val isBuiltin: Boolean get() = !id.startsWith("custom-")

    companion object {
        /** 内置入口默认表（顺序即首页横滑顺序） */
        val builtins: List<QuickEntry> = listOf(
            QuickEntry("bottle", "bottle", "瓶喂", "🍼"),
            QuickEntry("breast", "breast", "亲喂", "🤱"),
            QuickEntry("pumping", "pumping", "吸奶", "🧴"),
            QuickEntry("storage", "storage", "储奶", "🥛"),
            QuickEntry("sleep", "sleep", "睡眠", "😴"),
            QuickEntry("diaper", "diaper", "尿布", "🧷"),
            QuickEntry("solid", "solid", "辅食", "🍚"),
            QuickEntry("supplement", "supplement", "补剂", "💊"),
            QuickEntry("medicine", "medicine", "喂药", "🩺"),
            QuickEntry("temp", "temp", "体温", "🌡️"),
            QuickEntry("notebook", "notebook", "记事本", "📒"),
            QuickEntry("weight", "weight", "体重", "⚖️"),
            QuickEntry("height", "height", "身高", "📏"),
            QuickEntry("head", "head", "头围", "🧢"),
        )
    }
}

// MARK: - 设置

data class AppSettings(
    val weightUnit: String = "kg",     // kg / 斤
    val showFeed: Boolean = true,
    val showShot: Boolean = true,
    val showSize: Boolean = true,      // 鞋服尺码模块
    val showTrends: Boolean = true,    // 成长趋势模块
    val showLog: Boolean = false,      // 运行日志（独立开关，默认关）
    val darkMode: Boolean? = null,
    val fatherHeight: Double? = null,
    val motherHeight: Double? = null,
    /** 空列表 = 用内置默认顺序；用户改过之后写入完整列表 */
    val quickEntries: List<QuickEntry> = emptyList(),
    // MARK: 提醒（本机通知），与 iOS AppSettings 字段一致
    val growthReminderOn: Boolean = false,   // 定期测量提醒开关
    val growthReminderDays: Int = 30,        // 间隔天数：7=一周、30=一个月、90=三个月
    val growthReminderHour: Int = 9,         // 提醒时间（时）
    val growthReminderMinute: Int = 0,       // 提醒时间（分）
    val todoReminderOn: Boolean = true,      // 待办到期提醒开关
    /** 本机静音的待办 id（不随同步走：每台手机各自决定哪些待办不响，内容照样同步） */
    val mutedTodoReminders: Set<String> = emptySet(),
    // 每日用药/补剂提醒：开关 + 自定义时间列表（"HH:mm"），在补剂/喂药录入弹层里设置
    val suppReminderOn: Boolean = false,
    val suppReminderTimes: List<String> = emptyList(),   // 每天到点提醒吃补剂
    val medReminderOn: Boolean = false,
    val medReminderTimes: List<String> = emptyList(),    // 每天到点提醒吃药
) {
    val resolvedQuickEntries: List<QuickEntry>
        get() {
            if (quickEntries.isEmpty()) return QuickEntry.builtins
            // 老版本存过自定义顺序时，把后来新增的内置入口（储奶/喂药/记事本等）补在末尾
            val existing = quickEntries.map { it.kind }.toSet()
            return quickEntries + QuickEntry.builtins.filter { it.kind !in existing }
        }
}

// MARK: - 根状态

data class AppState(
    val children: List<Child> = emptyList(),
    val currentId: String? = null,
    val settings: AppSettings = AppSettings(),
    /** 删除墓碑：记录已删除条目的 key（如 "todo:<id>"），同步合并时据此过滤，防止旧副本复活 */
    val tombstones: Set<String> = emptySet(),
    /** 最近一次「清空全部数据」的时间戳（UTC yyyy-MM-dd'T'HH:mm:ss）。清空不同步删对方数据：对方收到提示自行选择 */
    val clearedAt: String? = null,
)
