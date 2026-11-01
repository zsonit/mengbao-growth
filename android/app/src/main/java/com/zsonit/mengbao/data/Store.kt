package com.zsonit.mengbao.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.zsonit.mengbao.model.AppState
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.FeedLog
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.model.QuickEntry
import com.zsonit.mengbao.model.Sex
import com.zsonit.mengbao.model.ShotRecord
import com.zsonit.mengbao.model.SizeRecord
import com.zsonit.mengbao.model.TodoItem
import java.io.File
import java.time.LocalDate
import java.time.LocalTime
import java.util.Locale
import java.util.UUID

/**
 * 本机数据仓库：JSON 存在应用私有目录，不联网、不上传。
 * 单例 + Compose State，任何写操作后自动落盘。
 */
object Store {

    private var file: File? = null
    private var appContext: Context? = null

    var state by mutableStateOf(AppState())
        private set

    fun init(context: Context) {
        if (file != null) return
        appContext = context.applicationContext
        val dir = File(context.filesDir, "MengBao")
        if (!dir.exists()) dir.mkdirs()
        val f = File(dir, "state.json")
        file = f
        state = try {
            if (f.exists()) JsonCodec.decode(f.readText()) else AppState()
        } catch (e: Exception) {
            com.zsonit.mengbao.data.AppLog.e("Store", "读取本机数据失败（可能数据文件损坏）：$e")
            AppState()
        }
        if (state.currentId == null) {
            state = state.copy(currentId = state.children.firstOrNull()?.id)
        }
        SyncManager.bootstrap(context)
    }

    // MARK: 只读派生

    val current: Child?
        get() = state.currentId?.let { id -> state.children.firstOrNull { it.id == id } }

    val settings get() = state.settings

    // MARK: 写

    /** 同步引擎回写数据时置 true，避免回写再触发新一轮同步造成乒乓 */
    internal var suppressSync = false

    fun update(block: (AppState) -> AppState) {
        state = block(state)
        persist()
        if (!suppressSync) SyncManager.onDataChanged()
    }

    fun updateCurrent(block: (Child) -> Child) {
        val id = state.currentId ?: return
        update { s ->
            s.copy(children = s.children.map {
                if (it.id == id) block(it).copy(updatedAt = java.time.LocalDateTime.now()) else it
            })
        }
    }

    private fun persist() {
        val f = file ?: return
        runCatching { f.writeText(JsonCodec.encode(state)) }
    }

    // MARK: 孩子

    fun addChild(name: String, sex: Sex, birthDate: LocalDate, avatar: String): String {
        val child = Child(name = name, sex = sex, birthDate = birthDate, avatar = avatar, updatedAt = java.time.LocalDateTime.now())
        update { it.copy(children = it.children + child, currentId = child.id) }
        return child.id
    }

    fun selectChild(id: String) = update { it.copy(currentId = id) }

    fun updateChild(child: Child) = update { s ->
        s.copy(children = s.children.map { if (it.id == child.id) child.copy(updatedAt = java.time.LocalDateTime.now()) else it })
    }

    fun deleteChild(id: String) = update { s ->
        val rest = s.children.filterNot { it.id == id }
        s.copy(children = rest, currentId = if (s.currentId == id) rest.firstOrNull()?.id else s.currentId)
    }

    // MARK: 生长记录

    fun addRecord(record: GrowthRecord) = updateCurrent { child ->
        child.copy(records = (child.records + record).sortedBy { it.date })
    }

    fun updateRecord(record: GrowthRecord) = updateCurrent { child ->
        val exists = child.records.any { it.id == record.id }
        val list = if (exists) child.records.map { if (it.id == record.id) record else it }
        else child.records + record
        child.copy(records = list.sortedBy { it.date })
    }

    fun deleteRecord(id: String) = updateCurrent { c -> c.copy(records = c.records.filterNot { it.id == id }) }

    // MARK: 喂养

    fun addFeed(log: FeedLog) = updateCurrent { c -> c.copy(feeds = c.feeds + log) }

    fun deleteFeed(id: String) = updateCurrent { c -> c.copy(feeds = c.feeds.filterNot { it.id == id }) }

    // MARK: 尺码

    /**
     * 保存尺码：同一天已有记录时「更新那一条」而不是再追加一条。
     * 以前是纯追加，用户每改一次就多一条，几天下来同一天堆了 7 条，
     * 两端还各自取到不同的那条，看起来就像「没同步」。
     */
    fun addSize(record: SizeRecord) = updateCurrent { c ->
        val same = c.sizes.maxByOrNull { if (it.date == record.date) it.filledCount else -1 }
            ?.takeIf { it.date == record.date }
        val list = if (same == null) {
            c.sizes + record
        } else {
            c.sizes.map { if (it.id == same.id) record.copy(id = same.id).fillMissingFrom(same) else it }
        }
        c.copy(sizes = list.sortedBy { it.date })
    }

    fun deleteSize(id: String) = updateCurrent { c -> c.copy(sizes = c.sizes.filterNot { it.id == id }) }

    // MARK: 接种

    /** 保存自选（自费）疫苗勾选结果 */
    fun setOptVaccines(ids: List<String>) = updateCurrent { child ->
        child.copy(optVaccines = ids.ifEmpty { null })
    }

    fun toggleShot(key: String) = updateCurrent { child ->
        val shots = child.shots.toMutableMap()
        if (shots.containsKey(key)) shots.remove(key) else shots[key] = ShotRecord(LocalDate.now())
        child.copy(shots = shots)
    }

    // MARK: 待办

    fun addTodo(todo: TodoItem) = updateCurrent { c -> c.copy(todos = c.todos + todo) }

    /** 语音一次说好几条时批量加入：只触发一次保存 / 一次同步 */
    fun addTodos(items: List<TodoItem>) {
        if (items.isEmpty()) return
        updateCurrent { c -> c.copy(todos = c.todos + items) }
    }

    fun toggleTodo(id: String) = updateCurrent { child ->
        child.copy(todos = child.todos.map { if (it.id == id) it.copy(done = !it.done) else it })
    }

    fun deleteTodo(id: String) = updateCurrent { c -> c.copy(todos = c.todos.filterNot { it.id == id }) }

    // MARK: 设置

    fun setWeightUnit(unit: String) = update { it.copy(settings = it.settings.copy(weightUnit = unit)) }
    fun setShowFeed(on: Boolean) = update { it.copy(settings = it.settings.copy(showFeed = on)) }
    fun setShowSize(on: Boolean) = update { it.copy(settings = it.settings.copy(showSize = on)) }
    fun setShowLog(on: Boolean) = update { it.copy(settings = it.settings.copy(showLog = on)) }
    fun setShowShot(on: Boolean) = update { it.copy(settings = it.settings.copy(showShot = on)) }
    fun setDarkMode(value: Boolean?) = update { it.copy(settings = it.settings.copy(darkMode = value)) }
    fun setParents(father: Double?, mother: Double?) =
        update { it.copy(settings = it.settings.copy(fatherHeight = father, motherHeight = mother)) }

    // MARK: 快捷入口

    val quickEntries: List<QuickEntry> get() = settings.resolvedQuickEntries

    /** 首页要展示的入口（喂养模块关闭时过滤掉喂养类） */
    val homeQuickEntries: List<QuickEntry>
        get() {
            val feedKinds = setOf("bottle", "breast", "pumping", "solid", "supplement")
            return quickEntries.filter { it.visible && (settings.showFeed || it.kind !in feedKinds) }
        }

    fun setQuickEntries(entries: List<QuickEntry>) =
        update { it.copy(settings = it.settings.copy(quickEntries = entries)) }

    fun moveQuickEntry(from: Int, to: Int) {
        val list = quickEntries.toMutableList()
        if (from !in list.indices || to !in list.indices) return
        list.add(to, list.removeAt(from))
        setQuickEntries(list)
    }

    fun toggleQuickEntry(id: String) {
        setQuickEntries(quickEntries.map { if (it.id == id) it.copy(visible = !it.visible) else it })
    }

    fun addCustomQuickEntry(title: String, icon: String) {
        val id = "custom-" + UUID.randomUUID().toString().uppercase()
        setQuickEntries(quickEntries + QuickEntry(id = id, kind = "custom", title = title, icon = icon))
    }

    fun deleteQuickEntry(id: String) = setQuickEntries(quickEntries.filterNot { it.id == id })

    fun resetQuickEntries() = update { it.copy(settings = it.settings.copy(quickEntries = emptyList())) }

    // MARK: 导入导出

    fun exportJson(): String = JsonCodec.encode(state)

    fun importJson(text: String): Result<Unit> = runCatching {
        val decoded = JsonCodec.decode(text)
        update { decoded.copy(currentId = decoded.currentId ?: decoded.children.firstOrNull()?.id) }
    }

    fun exportCsv(child: Child): String {
        val sb = StringBuilder()
        sb.appendLine("日期,年龄,身高cm,体重kg,BMI,身高百分位,体重百分位,脚长cm,头围cm,备注")
        for (r in child.sortedRecords) {
            val e = GrowthMath.evaluate(child, r)
            val row = listOf(
                GrowthMath.dateString(r.date),
                GrowthMath.ageText(child.birthDate, r.date),
                r.height?.let { String.format(Locale.US, "%.1f", it) } ?: "",
                r.weight?.let { String.format(Locale.US, "%.1f", it) } ?: "",
                e.bmi?.let { String.format(Locale.US, "%.1f", it) } ?: "",
                e.heightPercentile?.let { String.format(Locale.US, "%.1f", it) } ?: "",
                e.weightPercentile?.let { String.format(Locale.US, "%.1f", it) } ?: "",
                r.footLength?.let { String.format(Locale.US, "%.1f", it) } ?: "",
                r.headCirc?.let { String.format(Locale.US, "%.1f", it) } ?: "",
                r.note.replace(",", "，"),
            )
            sb.appendLine(row.joinToString(","))
        }
        return sb.toString()
    }

    fun reset() = update { it.copy(children = emptyList(), currentId = null) }

    // MARK: 示例数据

    fun loadDemo() {
        val sister = Child(
            name = "珊", sex = Sex.GIRL, birthDate = LocalDate.of(2015, 10, 24), avatar = "👧",
            records = listOf(
                GrowthRecord(date = LocalDate.of(2025, 10, 24), height = 135.5, weight = 24.0, footLength = 24.0),
                GrowthRecord(date = LocalDate.of(2026, 4, 24), height = 135.8, weight = 24.2, footLength = 24.0),
                GrowthRecord(
                    date = LocalDate.of(2026, 10, 24), height = 136.0, weight = 24.3, footLength = 24.0,
                    note = "晨起空腹、脱鞋测量",
                ),
            ),
            sizes = listOf(SizeRecord(date = LocalDate.of(2026, 10, 24), footLength = 24.0, height = 136.0, note = "换季运动鞋，内长留 0.6cm")),
            todos = listOf(
                TodoItem(title = "预约 6 岁百白破加强针", done = true),
                TodoItem(title = "每半年测一次身高体重"),
            ),
        )
        val shots = mutableMapOf<String, ShotRecord>()
        GrowthMath.schedule(sister).filter { it.months <= 72 }.dropLast(1).forEach {
            shots[it.key] = ShotRecord(it.dueDate)
        }
        val sisterDone = sister.copy(shots = shots)

        val brotherBase = Child(
            name = "弟弟", sex = Sex.BOY, birthDate = LocalDate.of(2026, 3, 15), avatar = "👦",
            records = listOf(
                GrowthRecord(date = LocalDate.of(2026, 5, 15), height = 65.5, weight = 7.2, footLength = 11.5),
                GrowthRecord(date = LocalDate.of(2026, 7, 15), height = 70.0, weight = 8.3, footLength = 11.5),
                GrowthRecord(date = LocalDate.of(2026, 9, 15), height = 72.2, weight = 9.2, footLength = 11.5),
            ),
            sizes = listOf(SizeRecord(date = LocalDate.of(2026, 9, 15), footLength = 11.5, height = 72.2, note = "学步鞋 12 码")),
        )
        val feeds = mutableListOf<FeedLog>()
        for (i in 0 until 3) {
            val day = LocalDate.now().minusDays(i.toLong())
            feeds.add(FeedLog(date = day, time = LocalTime.of(20, 30), kind = FeedLog.Kind.SLEEP, minutes = 420 + i * 40))
            feeds.add(FeedLog(date = day, time = LocalTime.of(7, 10), kind = FeedLog.Kind.BOTTLE, ml = (180 + i * 20).toDouble()))
            feeds.add(FeedLog(date = day, time = LocalTime.of(12, 5), kind = FeedLog.Kind.BREAST, minutes = 15, side = if (i % 2 == 0) "左" else "右"))
            feeds.add(FeedLog(date = day, time = LocalTime.of(15, 20), kind = FeedLog.Kind.DIAPER, diaperKind = "小便"))
        }
        val brother = brotherBase.copy(feeds = feeds)

        update {
            it.copy(
                children = listOf(sisterDone, brother),
                currentId = sisterDone.id,
                settings = it.settings.copy(fatherHeight = 175.0, motherHeight = 163.0),
            )
        }
    }
}
