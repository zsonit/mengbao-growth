package com.zsonit.mengbao.data

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.io.File
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 自动备份：有数据更新就自动写一份 JSON 到应用专属目录。
 * 只保留最新一份——新备份直接覆盖旧文件，不会产生多余的备份文件。
 */
object AutoBackup {
    private const val DELAY_MS = 5_000L

    private var dir: File? = null
    private val handler = Handler(Looper.getMainLooper())
    private val scheduled = AtomicBoolean(false)

    /** 备份文件（应用专属外部存储，卸载才会删，无需任何存储权限） */
    val file: File?
        get() = dir?.let { File(it, "auto-backup.json") }

    fun init(context: Context) {
        dir = File(context.getExternalFilesDir(null), "backup").apply { mkdirs() }
    }

    /** 最近一次自动备份时间（供「数据管理」展示） */
    fun lastBackupAt(): LocalDateTime? = file?.takeIf { it.exists() }?.let {
        runCatching {
            LocalDateTime.ofInstant(Instant.ofEpochMilli(it.lastModified()), ZoneId.systemDefault())
        }.getOrNull()
    }

    /** 从自动备份恢复（成功返回 true） */
    fun restore(): Boolean {
        val text = file?.takeIf { it.exists() }?.let { runCatching { it.readText() }.getOrNull() }
            ?: return false
        return Store.importJson(text).isSuccess
    }

    /** Store 每次写数据后调用：防抖 5 秒写盘（连续输入只备份一次） */
    fun noteChange() {
        if (dir == null) return
        if (!scheduled.compareAndSet(false, true)) return
        handler.postDelayed({
            scheduled.set(false)
            val f = file ?: return@postDelayed
            runCatching { f.writeText(Store.exportJson()) }
        }, DELAY_MS)
    }
}
