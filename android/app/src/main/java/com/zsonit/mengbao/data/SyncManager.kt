package com.zsonit.mengbao.data

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.zsonit.mengbao.model.AppState
import com.zsonit.mengbao.model.Child
import com.zsonit.mengbao.model.GrowthRecord
import com.zsonit.mengbao.model.SizeRecord
import com.zsonit.mengbao.model.ToothDecay
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.UUID

/**
 * 配对同步引擎。
 *
 * 两台手机各自生成/输入同一个 6 位配对码，数据快照存放在云端一张按码索引的表里；
 * 本地有改动 → 防抖 3 秒后「拉取 → 记录级合并 → 推送」，App 启动和手动同步同一条链路。
 * 传输内容与「导出备份」完全相同的互通 JSON，全程仅存配对码对应的一行。
 *
 * 合并规则（两端实现保持一致）：
 * - 孩子：按 id 并集；同一孩子以 updatedAt 更新的一端为「权威端」；
 * - 权威端决定档案字段（姓名/生日/头像）与重复键记录的内容；
 * - 生长记录按日期并集、喂养/尺码/待办按 id 并集、接种/换牙按键并集，双方独有记录都保留；
 * - 显示设置以本机为准。
 */
object SyncManager {

    private const val ENDPOINT = "https://mengbao-sync.app.workbuddy.host"
    private const val PUBLISHABLE_KEY = "wbpk_z3Qd2DmHRK20lYTyzpjsTH_DG9v1WdRyKgkBsMLewH3mh5Br7EOcUlR"
    private const val REST = "$ENDPOINT/.cloud/database/rest/v1/mengbao_sync"
    private const val PREFS = "mengbao_sync"
    private const val KEY_CODE = "code"
    private const val KEY_DEVICE = "device_id"
    private const val KEY_LAST_SYNC = "last_sync_at"
    private const val KEY_SALT = "salt"
    private const val KEY_REV = "last_rev"
    /// 前台自动检查间隔：对端改完后最多这么久就能看到
    private const val POLL_MS = 6_000L
    /// 本机改动后的防抖：够快、又能合并连续输入
    private const val DEBOUNCE_MS = 1_200L
    /// fetchRemote 的解密失败标记
    private const val UNDECRYPTABLE = "undecryptable"
    /// 云端还没有这一行的标记
    private const val EMPTY = "empty"

    private var appContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pollHandler = Handler(Looper.getMainLooper())
    private val syncLock = Any()

    /** 本机有未推送的修改；没有就不推，避免两端互推蹭出无限循环 */
    @Volatile private var localDirty = false
    /** 同步进行中又来了新改动：等这一轮结束后必须补跑一次，否则这次改动会被丢掉 */
    @Volatile private var retryPending = false
    private var lastRev: Long = 0L

    private val pollRunnable = object : Runnable {
        override fun run() {
            Thread { pollOnce() }.start()
            pollHandler.postDelayed(this, POLL_MS)
        }
    }

    // UI 可观察状态
    var busy by mutableStateOf(false)
        private set
    var lastMessage by mutableStateOf<String?>(null)
        private set
    var lastSyncAt by mutableStateOf(0L)
        private set

    val pairedCode: String?
        get() = prefs()?.getString(KEY_CODE, null)

    fun bootstrap(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        lastSyncAt = prefs()?.getLong(KEY_LAST_SYNC, 0L) ?: 0L
        lastRev = prefs()?.getLong(KEY_REV, 0L) ?: 0L
        // 启动后拉一次云端（延迟几秒，避开启动高峰）
        if (pairedCode != null) {
            mainHandler.postDelayed({ Thread { syncNow(manual = false) }.start() }, 4000)
        }
    }

    // MARK: 前台自动刷新

    /** App 回到前台：立即同步一次，然后开启轮询 */
    fun onForeground() {
        if (pairedCode == null) return
        pollHandler.removeCallbacks(pollRunnable)
        pollHandler.postDelayed(pollRunnable, 1200)
    }

    /** App 退到后台：停止轮询（不耗电、不耗流量），但把还没推上去的改动抢推一次 */
    fun onBackground() {
        pollHandler.removeCallbacks(pollRunnable)
        if (localDirty && !busy) {
            AppLog.i("Sync", "退到后台，补推未上传的改动")
            Thread { syncNow(manual = false) }.start()
        }
    }

    /** 轻量检查：只拉版本号，变了才真同步 */
    private fun pollOnce() {
        if (busy) return
        val code = pairedCode ?: return
        // 本机有改动还没推成功（上一轮撞上忙碌被跳过了）：直接补推，别干等 rev 变化
        if (localDirty) {
            syncNow(manual = false)
            return
        }
        val (body, _) = http("GET", "$REST?code=eq.$code&select=rev,updated_by&limit=1", null)
        if (body == null) return
        val row = runCatching { JSONArray(body).optJSONObject(0) }.getOrNull() ?: return
        val remoteRev = row.optLong("rev", 0L)
        val by = row.optString("updated_by")
        if (remoteRev == lastRev) return
        if (by == deviceId()) {
            // 自己推的那次没记上版本号，补上即可
            setRev(remoteRev)
            return
        }
        AppLog.i("Sync", "检测到对方有新数据（rev=$remoteRev），开始自动同步")
        syncNow(manual = false)
    }

    private fun setRev(rev: Long) {
        lastRev = rev
        prefs()?.edit()?.putLong(KEY_REV, rev)?.apply()
    }

    private fun prefs() = appContext?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun deviceId(): String {
        val p = prefs() ?: return "unknown"
        var id = p.getString(KEY_DEVICE, null)
        if (id == null) {
            id = UUID.randomUUID().toString().substring(0, 8)
            p.edit().putString(KEY_DEVICE, id).apply()
        }
        return id
    }

    // MARK: 配对操作（在调用方线程执行网络；UI 层用 Thread 包裹）

    /** 创建配对码：随机 6 位数字，云端已占用则换号重试；创建后立即推送本机快照 */
    fun createPairing(): SyncResult {
        repeat(6) {
            val code = (100000..999999).random().toString()
            val exists = codeExists(code)
            if (exists == false) {
                prefs()?.edit()?.putString(KEY_CODE, code)?.remove(KEY_SALT)?.apply()
                val r = syncNow(manual = true)
                return if (r.ok) SyncResult(true, "配对码 $code 已就绪") else r
            }
        }
        return SyncResult(false, "配对码生成失败，请检查网络后重试")
    }

    /** 加入对方的配对码：存码后立即拉取合并 */
    fun joinPairing(code: String): SyncResult {
        val c = code.trim()
        if (!Regex("\\d{6}").matches(c)) return SyncResult(false, "配对码是 6 位数字")
        prefs()?.edit()?.putString(KEY_CODE, c)?.remove(KEY_SALT)?.apply()
        val r = syncNow(manual = true)
        return if (r.ok) SyncResult(true, "配对成功：$c") else r
    }

    /**
     * 解除配对：只停止同步。本机资料、云端资料全部保留，只是不再互通。
     * 多部手机共用一个配对码时（爷爷奶奶等），任何一台退出都不影响其他人。
     */
    fun unlink(): SyncResult {
        clearLocal()
        return SyncResult(true, "已解除配对：本机与云端资料都保留，只是不再同步")
    }

    private fun clearLocal() {
        prefs()?.edit()?.clear()?.apply()
        lastSyncAt = 0
        lastMessage = null
        localDirty = false
        lastRev = 0L
        pollHandler.removeCallbacks(pollRunnable)
    }

    // MARK: 同步主链路

    fun onDataChanged() {
        localDirty = true
        // 正在同步：记一笔，等这一轮结束立刻补推（以前这里直接 return，改动就永远丢了）
        if (busy) {
            retryPending = true
            return
        }
        scheduleSync(DEBOUNCE_MS)
    }

    /** 打一次延时的自动同步（连续改动会重置计时，合并成一次推送） */
    private fun scheduleSync(delayMs: Long) {
        mainHandler.removeCallbacksAndMessages(null)
        mainHandler.postDelayed({ Thread { syncNow(manual = false) }.start() }, delayMs)
    }

    /** 页面打开等场景主动拉一次（不阻塞调用线程） */
    fun requestSync() {
        if (busy) {
            retryPending = true
            return
        }
        Thread { syncNow(manual = false) }.start()
    }

    fun syncNow(manual: Boolean): SyncResult = synchronized(syncLock) {
        val context = appContext
        val code = pairedCode
        if (context == null || code == null) return SyncResult(false, "尚未配对")
        if (Store.state.children.isEmpty()) {
            // 本机没数据：只拉不推，避免把空数据盖掉对方
            val remote = fetchRemote(code)
                ?: return if (manual) SyncResult(true, "云端暂无数据") else SyncResult(false, "云端暂无数据")
            if (remote.updatedBy == UNDECRYPTABLE) {
                val msg = "云端数据无法解密，请重新输入配对码"
                lastMessage = msg
                return SyncResult(false, msg)
            }
            applyRemote(context, code, remote)
            return SyncResult(true, "已拉取对方资料")
        }
        busy = true
        try {
            val remote = fetchRemote(code) // null=网络失败；空 payload=对方还没推过
            if (remote != null && remote.updatedBy == UNDECRYPTABLE) {
                // 解密不了多半是两端密钥/配对码对不上，此时绝不能拿本机数据覆盖云端，否则另一端会被清空
                val msg = "云端数据无法解密，请重新输入配对码"
                lastMessage = msg
                AppLog.w("Sync", msg)
                return SyncResult(false, msg)
            }
            val local = Store.state
            var merged = local
            // 云端还没有这一行（刚创建配对码）时必须推一次，否则对方永远拉不到数据
            var mustPush = localDirty || lastRev == 0L || remote?.updatedBy == EMPTY
            if (remote != null) {
                merged = mergeState(local, remote.state)
                if (merged != local) {
                    Store.suppressSync = true
                    try {
                        Store.update { merged.copy(currentId = merged.currentId ?: merged.children.firstOrNull()?.id) }
                    } finally {
                        Store.suppressSync = false
                    }
                    mustPush = true
                }
            }
            if (!mustPush) {
                // 本机没改、云端也没新东西：什么都不推，避免两端互相蹭出无限推送
                lastMessage = "已是最新"
                return SyncResult(true, "已是最新")
            }
            val resp = upsert(code, merged)
            if (!resp.ok) {
                lastMessage = if (manual) "推送失败：${resp.message}" else null
                AppLog.w("Sync", "推送失败：${resp.message}")
                return SyncResult(false, "推送失败：${resp.message}")
            }
            localDirty = false
            val ts = System.currentTimeMillis()
            lastSyncAt = ts
            prefs()?.edit()?.putLong(KEY_LAST_SYNC, ts)?.apply()
            val mergedNew = remote != null && merged != local
            lastMessage = if (mergedNew) "已同步（收到对方的新记录）" else "已同步"
            if (manual) AppLog.i("Sync", "手动同步完成：${merged.children.size} 个宝宝")
            return SyncResult(true, lastMessage ?: "已同步")
        } catch (e: Exception) {
            AppLog.e("Sync", "同步异常：$e")
            lastMessage = if (manual) "同步失败：${e.message}" else null
            return SyncResult(false, "同步失败：${e.message}")
        } finally {
            busy = false
            // 这一轮同步期间又存了新数据：立刻补跑一轮，避免改动丢失
            if (retryPending) {
                retryPending = false
                scheduleSync(600)
            }
        }
    }

    /** 首次绑定（本机无数据时）：直接采用对方数据 */
    private fun applyRemote(context: Context, code: String, remote: RemoteSnapshot): SyncResult {
        busy = true
        try {
            Store.suppressSync = true
            try {
                Store.update {
                    remote.state.copy(currentId = remote.state.currentId ?: remote.state.children.firstOrNull()?.id)
                }
            } finally {
                Store.suppressSync = false
            }
            val payload = Store.state
            val resp = upsert(code, payload)
            if (resp.ok) localDirty = false
            val ts = System.currentTimeMillis()
            lastSyncAt = ts
            prefs()?.edit()?.putLong(KEY_LAST_SYNC, ts)?.apply()
            lastMessage = if (resp.ok) "已拉取对方资料" else "拉取成功但推送失败"
            return SyncResult(resp.ok, lastMessage ?: "已拉取")
        } finally {
            busy = false
        }
    }

    // MARK: 合并

    private fun mergeState(local: AppState, remote: AppState): AppState {
        val children = mutableListOf<Child>()
        val remoteById = remote.children.associateBy { it.id }
        val seen = mutableSetOf<String>()
        for (l in local.children) {
            seen.add(l.id)
            children.add(remoteById[l.id]?.let { mergeChild(l, it) } ?: l)
        }
        for (r in remote.children) {
            if (r.id !in seen) children.add(r)
        }
        return local.copy(children = children)
    }

    private fun authIsLocal(l: Child, r: Child): Boolean {
        val lt = l.updatedAt ?: l.createdAt.atStartOfDay().minusYears(50)
        val rt = r.updatedAt ?: r.createdAt.atStartOfDay().minusYears(50)
        return lt >= rt
    }

    private fun mergeChild(l: Child, r: Child): Child {
        val auth = if (authIsLocal(l, r)) l else r
        val other = if (auth === l) r else l
        return auth.copy(
            records = mergeRecords(auth.records, other.records),
            feeds = mergeById(auth.feeds, other.feeds),
            sizes = dedupeSizes(mergeById(auth.sizes, other.sizes)),
            todos = mergeById(auth.todos, other.todos),
            shots = mergeMaps(auth.shots, other.shots),
            teethFallen = mergeTeeth(auth, other),
            teethDecay = mergeTeethDecay(auth, other),
        )
    }

    /** 生长记录按日期并集；同一天的字段互补（权威端优先，空位用另一端补） */
    private fun mergeRecords(a: List<GrowthRecord>, b: List<GrowthRecord>): List<GrowthRecord> {
        val byDate = a.associateBy { it.date }.toMutableMap()
        for (r in b) {
            val base = byDate[r.date]
            byDate[r.date] = when {
                base == null -> r
                base === r -> base
                else -> base.copy(
                    height = base.height ?: r.height,
                    weight = base.weight ?: r.weight,
                    footLength = base.footLength ?: r.footLength,
                    headCirc = base.headCirc ?: r.headCirc,
                    note = base.note.ifEmpty { r.note },
                )
            }
        }
        return byDate.values.sortedBy { it.date }
    }

    private inline fun <reified T> mergeById(a: List<T>, b: List<T>): List<T> {
        // 元素带 id 属性：按 id 并集，重复 id 保留权威端（a）的内容
        return if (b.isEmpty()) a else a + b.filter { o -> a.none { anyId(it) == anyId(o) } }
    }

    /**
     * 尺码去重（按天归并）：同一天只保留一条。
     * 老版本每次保存都追加，同一天能堆出好几条（有的只有腰围、有的最全），
     * 两端「取最新一条」时各挑到不同那条，看起来就像同步失败。
     * 现在以「字段最全」的那条为底，用同一天其它条补齐空缺，冲突时以最全的为准。
     */
    private fun dedupeSizes(list: List<SizeRecord>): List<SizeRecord> =
        list.filter { it.hasContent }
            .groupBy { it.dayKey }
            .values
            .map { group ->
                val base = group.maxWith(compareBy({ it.filledCount }, { it.id }))
                group.fold(base) { acc, s -> acc.fillMissingFrom(s) }
            }
            .sortedBy { it.date }

    private fun anyId(x: Any?): String? = when (x) {
        is com.zsonit.mengbao.model.FeedLog -> x.id
        is com.zsonit.mengbao.model.SizeRecord -> x.id
        is com.zsonit.mengbao.model.TodoItem -> x.id
        else -> null
    }

    private fun <K, V> mergeMaps(a: Map<K, V>, b: Map<K, V>): Map<K, V> {
        val out = a.toMutableMap()
        b.forEach { (k, v) -> if (!out.containsKey(k)) out[k] = v }
        return out
    }

    private fun mergeTeeth(a: Child, b: Child): Map<Int, LocalDate>? {
        val am = a.teethFallen
        val bm = b.teethFallen
        if (am == null) return bm
        if (bm == null) return am
        val out = am.toMutableMap()
        bm.forEach { (k, v) -> if (!out.containsKey(k)) out[k] = v }
        return out.ifEmpty { null }
    }

    /** 龋齿记录同样按牙位并集，缺失的一侧补上（同一颗牙各自记录时以权威端为准） */
    private fun mergeTeethDecay(a: Child, b: Child): Map<Int, ToothDecay>? {
        val am = a.teethDecay
        val bm = b.teethDecay
        if (am == null) return bm
        if (bm == null) return am
        val out = am.toMutableMap()
        bm.forEach { (k, v) -> if (!out.containsKey(k)) out[k] = v }
        return out.ifEmpty { null }
    }

    // MARK: 网络与快照

    private class RemoteSnapshot(val state: AppState, val updatedBy: String)

    /** 查码是否已被占用；null = 网络失败 */
    private fun codeExists(code: String): Boolean? {
        val (body, status) = http("GET", "$REST?code=eq.$code&select=code&limit=1", null)
        if (status !in 200..299 || body == null) return null
        return JSONArray(body).length() > 0
    }

    /** 本机配对盐；没有则生成并保存 */
    private fun localSalt(): String {
        val p = prefs()
        val existing = p?.getString(KEY_SALT, null)
        if (existing != null) return existing
        val salt = SyncCrypto.newSalt()
        p?.edit()?.putString(KEY_SALT, salt)?.apply()
        return salt
    }

    /** 采用云端的盐（对方先创建配对时，两端必须用同一个盐才能互相解密） */
    private fun adoptSalt(remoteSalt: String) {
        val p = prefs() ?: return
        if (p.getString(KEY_SALT, null) != remoteSalt) {
            p.edit()?.putString(KEY_SALT, remoteSalt)?.apply()
        }
    }

    private fun fetchRemote(code: String): RemoteSnapshot? {
        val (body, _) = http("GET", "$REST?code=eq.$code&select=payload,updated_by,rev&limit=1", null)
        if (body == null) return null
        val arr = JSONArray(body)
        if (arr.length() == 0) return RemoteSnapshot(AppState(), EMPTY)
        val row = arr.optJSONObject(0) ?: return null
        setRev(row.optLong("rev", 0L))
        val payload = row.optJSONObject("payload") ?: return null

        // 新格式：端到端加密信封 —— 先采用云端盐，再用它解
        if (payload.has("ct")) {
            payload.optString("salt").takeIf { it.isNotEmpty() }?.let { adoptSalt(it) }
            val plain = SyncCrypto.decrypt(code, payload)
            if (plain == null) {
                // 解不开：配对码/盐对不上。返回标记让调用方跳过本轮，绝不能用本机数据覆盖云端
                AppLog.w("Sync", "云端密文无法解密（密钥不一致），本轮跳过，不覆盖云端")
                return RemoteSnapshot(AppState(), UNDECRYPTABLE)
            }
            return RemoteSnapshot(JsonCodec.decode(plain), row.optString("updated_by"))
        }

        // 旧格式兼容（2.5.1 及以前）：包裹结构 {v,device,ts,data} 或直接就是互通 JSON
        val data = payload.optJSONObject("data") ?: payload
        AppLog.i("Sync", "检测到旧版明文数据，本次同步后自动改成密文")
        return RemoteSnapshot(JsonCodec.decode(data.toString()), row.optString("updated_by"))
    }

    /** 推送：payload 列存加密信封，updated_by 记录来源设备，rev 供对端轻度轮询发现变化 */
    private fun upsert(code: String, state: AppState): SyncResult {
        val envelope = SyncCrypto.encrypt(code, JsonCodec.encode(state), localSalt())
            ?: return SyncResult(false, "本机加密失败")
        val rev = System.currentTimeMillis()
        val body = JSONObject()
            .put("code", code)
            .put("payload", envelope)
            .put("updated_by", deviceId())
            .put("rev", rev)
            .toString()
        val (errBody, status) = http(
            "POST",
            "$REST?on_conflict=code",
            body,
            extraHeaders = mapOf("Prefer" to "resolution=merge-duplicates"),
        ) ?: return SyncResult(false, "网络不可用")
        if (status in 200..299) {
            setRev(rev)
            return SyncResult(true, "OK")
        }
        val detail = errBody?.let {
            runCatching { JSONObject(it).optString("message") }.getOrNull()
        }
        return SyncResult(false, "HTTP $status${detail?.let { "：${it.take(80)}" } ?: ""}")
    }

    /** 返回 (响应体, HTTP 状态码)；网络异常返回 (null, 0) */
    private fun http(
        method: String,
        url: String,
        body: String?,
        extraHeaders: Map<String, String> = emptyMap(),
    ): Pair<String?, Int> {
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15000
                readTimeout = 20000
                setRequestProperty("x-wb-webapp-access-key", PUBLISHABLE_KEY)
                setRequestProperty("Content-Type", "application/json")
                extraHeaders.forEach { (k, v) -> setRequestProperty(k, v) }
                if (body != null) doOutput = true
            }
            body?.let { text -> conn.outputStream.use { it.write(text.toByteArray(Charsets.UTF_8)) } }
            val status = conn.responseCode
            val stream = if (status in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.use { it.readBytes().toString(Charsets.UTF_8) }
            text to status
        } catch (e: Exception) {
            AppLog.w("Sync", "网络请求失败：$method $e")
            null to 0
        } finally {
            conn?.disconnect()
        }
    }
}

data class SyncResult(val ok: Boolean, val message: String)
