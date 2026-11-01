import Foundation

/// 运行日志：排查崩溃与异常用。
///  - 崩溃捕获永远开启（NSException 未捕获时写入日志）；
///  - 普通调试日志受「独立开关」控制，默认关闭；
///  - 文件在 Documents/logs/app.log（「文件」App 可见），超 512KB 滚动为 app.old.log。
enum AppLog {

    private static let maxBytes = 512 * 1024
    private static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "applog.enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "applog.enabled") }
    }

    static var isEnabled: Bool {
        get { enabled }
        set {
            enabled = newValue
            if newValue { i("AppLog", "运行日志已开启") }
        }
    }

    static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = docs.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("app.log")
    }

    static func bootstrap() {
        NSSetUncaughtExceptionHandler(mengbaoUncaughtHandler)
    }

    static func i(_ tag: String, _ msg: String) { write(level: "INFO", tag: tag, msg: msg) }
    static func w(_ tag: String, _ msg: String) { write(level: "WARN", tag: tag, msg: msg) }
    static func e(_ tag: String, _ msg: String) { write(level: "ERROR", tag: tag, msg: msg) }

    /// 供顶层崩溃处理函数调用（绕过 private 限制）
    static func writeCrash(_ detail: String) { write(level: "CRASH", tag: "EXCEPTION", msg: detail) }

    private static let ts: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }()

    private static func write(level: String, tag: String, msg: String) {
        let line = "\(ts.string(from: Date())) [\(level)] \(tag): \(msg.prefix(1200))\n"
        let alwaysDisk = level == "CRASH" || level == "ERROR"
        if !enabled && !alwaysDisk { return }
        let url = fileURL
        let fm = FileManager.default
        if let data = line.data(using: .utf8) {
            if let size = try? fm.attributesOfItem(atPath: url.path)[.size] as? Int, size > maxBytes {
                let old = url.deletingLastPathComponent().appendingPathComponent("app.old.log")
                try? fm.removeItem(at: old)
                try? fm.moveItem(at: url, to: old)
            }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    static func readAll() -> String {
        let fm = FileManager.default
        var text = ""
        if let current = try? String(contentsOf: fileURL, encoding: .utf8) { text = current }
        let old = fileURL.deletingLastPathComponent().appendingPathComponent("app.old.log")
        if let previous = try? String(contentsOf: old, encoding: .utf8) {
            text = previous + (text.isEmpty ? "" : "\n---- 本次文件 ----\n" + text)
        }
        return text.isEmpty ? "（暂无日志）" : String(text.suffix(60_000))
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent().appendingPathComponent("app.old.log"))
        if enabled { i("AppLog", "日志已清空") }
    }
}

/// 顶层函数：NSSetUncaughtExceptionHandler 需要 C 函数指针，闭包会捕获上下文报错
private func mengbaoUncaughtHandler(_ ex: NSException) {
    let detail = "\(ex.name.rawValue): \(ex.reason ?? "")\n" +
        ex.callStackSymbols.prefix(40).joined(separator: "\n")
    AppLog.writeCrash(detail)
}
