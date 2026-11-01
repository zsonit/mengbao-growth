package com.zsonit.mengbao.data

import android.content.Context
import android.content.SharedPreferences
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 运行日志：排查崩溃与异常用。
 *  - 崩溃捕获**永远开启**（不做开关），未捕获异常会把堆栈写进日志再交给系统；
 *  - 普通调试日志（页面加载、接口、白屏检测等）受「独立开关」控制，默认关闭，不写不存；
 *  - 日志写在应用私有目录 logs/app.log（超过 512KB 自动滚动成 app.old.log），
 *    「我的 → 运行日志」里可查看 / 导出（分享文本）/ 清空。
 */
object AppLog {

    private const val DIR = "logs"
    private const val FILE = "app.log"
    private const val MAX_BYTES = 512 * 1024
    private const val MAX_BUFFER = 400

    private var appContext: Context? = null
    private val buffer = ArrayDeque<String>()
    private var enabled = false
    private val ts = SimpleDateFormat("MM-dd HH:mm:ss", Locale.CHINA)

    fun init(context: Context) {
        if (appContext != null) return
        appContext = context.applicationContext
        enabled = prefs().getBoolean("enabled", false)

        // 崩溃捕获：先写日志再交还系统默认处理（App 照常崩溃退出）
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { t, e ->
            runCatching {
                write("CRASH", "THREAD", "${t.name} 崩溃：${e.message}\n${e.stackTraceToString().take(5000)}")
            }
            previous?.uncaughtException(t, e)
        }
    }

    var isEnabled: Boolean
        get() = enabled
        set(on) {
            enabled = on
            prefs().edit().putBoolean("enabled", on).apply()
            if (on) i("AppLog", "运行日志已开启")
        }

    fun i(tag: String, msg: String) = write("INFO", tag, msg)
    fun w(tag: String, msg: String) = write("WARN", tag, msg)
    fun e(tag: String, msg: String) = write("ERROR", tag, msg)

    private fun prefs(): SharedPreferences =
        appContext!!.getSharedPreferences("app_log", Context.MODE_PRIVATE)

    private fun logFile(): File? {
        val ctx = appContext ?: return null
        val dir = File(ctx.filesDir, DIR)
        if (!dir.exists()) dir.mkdirs()
        return File(dir, FILE)
    }

    @Synchronized
    private fun write(level: String, tag: String, msg: String) {
        val line = "${ts.format(Date())} [$level] $tag: ${msg.take(1200)}"
        buffer.addLast(line)
        while (buffer.size > MAX_BUFFER) buffer.removeFirst()

        // 崩溃与错误始终落盘；普通日志看开关
        val alwaysDisk = level == "CRASH" || level == "ERROR"
        if (!enabled && !alwaysDisk) return

        val f = logFile() ?: return
        runCatching {
            if (f.length() > MAX_BYTES) {
                val old = File(f.parentFile, "app.old.log")
                if (old.exists()) old.delete()
                f.renameTo(old)
            }
            f.appendText(line + "\n")
        }
    }

    /** 内存缓冲 + 全部文件内容（给查看/导出用） */
    fun readAll(): String {
        val sb = StringBuilder()
        logFile()?.takeIf { it.exists() }?.let { sb.append(it.readText()) }
        if (buffer.isNotEmpty()) {
            if (sb.isNotEmpty()) sb.append("\n---- 本次启动的新日志 ----\n")
            buffer.forEach { sb.append(it).append("\n") }
        }
        return sb.toString().ifEmpty { "（暂无日志）" }
    }

    fun clear() {
        buffer.clear()
        runCatching {
            logFile()?.delete()
            File(logFile()?.parentFile, "app.old.log").delete()
        }
        if (enabled) i("AppLog", "日志已清空")
    }
}
