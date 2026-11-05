import Foundation
import UserNotifications

// MARK: - 本机提醒（量身高 / 待办到期）
//
// 全部走 UNUserNotificationCenter，在手机本地排程：不联网、不上传任何内容。
// 两类提醒：
//   ① 定期测量：按「上次测量日期 + 用户设的间隔」往后排多个周期，就算几周不打开 App 也会按时提醒；
//   ② 待办到期：截止前一天 20:00 预告一次，当天 9:00 再提醒一次。
// 每次数据变动 / 每次启动都会重排一遍，保证提醒和当前数据一致（已完成的待办不再提醒）。

final class NotificationManager {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    /// 定期测量一次往前排几个周期（App 长期不打开也能撑住）
    private static let growthSlots = 8
    /// 待办提醒最多排多少条（系统单 App 上限 64 条，留余量）
    private static let todoLimit = 20

    private let growthPrefix = "mb.growth."
    private let todoPrefix = "mb.todo."
    private let bdayPrefix = "mb.bday."
    private let suppPrefix = "mb.supp."
    private let medPrefix = "mb.med."

    /// 自己排的全部提醒前缀（重排前先清掉这些，避免残留）
    private var allPrefixes: [String] { [growthPrefix, todoPrefix, bdayPrefix, suppPrefix, medPrefix] }

    // MARK: 授权

    /// 没询问过就弹一次系统授权；已被拒绝回调 false，界面据此提示去设置里打开
    func ensureAuthorized(_ completion: ((Bool) -> Void)? = nil) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error { AppLog.e("Notify", "申请通知权限失败：\(error)") }
                    AppLog.i("Notify", "通知权限：\(granted ? "已允许" : "被拒绝")")
                    DispatchQueue.main.async { completion?(granted) }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion?(true) }
            default:
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    // MARK: 总排程（清掉旧的，按当前数据重排）

    func reschedule(children: [Child], settings: AppSettings) {
        let onGrowth = settings.growthReminderOn
        let onTodo = settings.todoReminderOn
        center.getPendingNotificationRequests { pending in
            let stale = pending
                .map { $0.identifier }
                .filter { id in self.allPrefixes.contains { id.hasPrefix($0) } }
            if !stale.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: stale)
            }
            let anyBday = !children.filter({ $0.birthdayRemind ?? true }).isEmpty
            guard onGrowth || onTodo || anyBday || settings.suppReminderOn || settings.medReminderOn else { return }
            if onGrowth { self.addGrowth(children: children, settings: settings) }
            if onTodo { self.addTodos(children: children, settings: settings) }
            self.addBirthdays(children: children)
            self.addDoseReminders(settings: settings)
            self.debugList()
        }
    }

    /// 清空全部提醒（清空数据 / 关掉所有提醒时用）
    func cancelAll() {
        center.getPendingNotificationRequests { pending in
            let mine = pending
                .map { $0.identifier }
                .filter { id in self.allPrefixes.contains { id.hasPrefix($0) } }
            if !mine.isEmpty { self.center.removePendingNotificationRequests(withIdentifiers: mine) }
        }
    }

    // MARK: 每日补剂 / 用药提醒（开关 + 任意多个时间点，每天重复）

    private func addDoseReminders(settings: AppSettings) {
        let groups: [(prefix: String, on: Bool, times: [String], title: String, body: String)] = [
            (medPrefix, settings.medReminderOn, settings.medReminderTimes,
             "💊 该吃药啦", "到点给宝宝喂药，吃完记得在 App 里记一笔。"),
            (suppPrefix, settings.suppReminderOn, settings.suppReminderTimes,
             "🥛 该吃补剂啦", "到点啦，今天的补剂别忘了，吃完记得记一笔。"),
        ]
        for group in groups {
            guard group.on else { continue }
            for raw in group.times {
                let parts = raw.split(separator: ":")
                guard parts.count == 2,
                      let hour = Int(parts[0]), let minute = Int(parts[1]),
                      (0...23).contains(hour), (0...59).contains(minute) else { continue }
                var comps = DateComponents()
                comps.hour = hour
                comps.minute = minute
                let content = UNMutableNotificationContent()
                content.title = group.title
                content.body = group.body
                content.sound = .default
                let req = UNNotificationRequest(identifier: group.prefix + "\(hour).\(minute)",
                                                content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
                center.add(req, withCompletionHandler: { err in
                    if let err = err { AppLog.e("Notify", "排用药/补剂提醒失败：\(err)") }
                })
            }
        }
    }

    // MARK: 生日提醒（当天 / 提前 N 天，两个独立开关，时刻各自可调）

    private func addBirthdays(children: [Child]) {
        let cal = Calendar.current
        let now = Date()
        for child in children {
            let sameDayOn = child.bdaySameDayEnabled
            let advOn = child.bdayAdvanceEnabled
            guard sameDayOn || advOn else { continue }
            let birth = cal.dateComponents([.month, .day], from: child.birthDate)
            guard birth.month != nil, birth.day != nil else { continue }
            let sameMinutes = child.bdaySameDayMinutes
            let advMinutes = child.bdayAdvanceMinutes
            let advDays = child.bdayAdvanceDaysEffective

            // 之后两年的生日，重复排会自动覆盖
            for yearOffset in 0...1 {
                guard let base = cal.date(from: DateComponents(year: cal.component(.year, from: now) + yearOffset,
                                                               month: birth.month, day: birth.day)) else { continue }
                let age = cal.dateComponents([.year], from: child.birthDate, to: base).year ?? 0
                var items: [(offset: Int, minutes: Int, title: String, body: String)] = []
                if sameDayOn {
                    items.append((0, sameMinutes,
                                  "🎂 今天是\(child.name)的生日",
                                  "祝\(child.name) \(age) 岁生日快乐，记得吃蛋糕拍照记录！"))
                }
                if advOn {
                    let when = advDays == 1 ? "明天" : "\(advDays) 天后"
                    items.append((-advDays, advMinutes,
                                  "🎁 \(when)是\(child.name)的生日",
                                  "\(when)\(child.name)就 \(age) 岁啦，礼物和蛋糕可以提前准备。"))
                }
                for item in items {
                    guard let day = cal.date(byAdding: .day, value: item.offset, to: base) else { continue }
                    var comps = cal.dateComponents([.year, .month, .day], from: day)
                    comps.hour = item.minutes / 60
                    comps.minute = item.minutes % 60
                    guard let fire = cal.date(from: comps), fire > now else { continue }
                    let c = UNMutableNotificationContent()
                    c.title = item.title
                    c.body = item.body
                    c.sound = .default
                    let req = UNNotificationRequest(identifier: bdayPrefix + child.id.uuidString + ".y\(yearOffset).d\(item.offset)",
                                                    content: c,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                    center.add(req, withCompletionHandler: nil)
                }
            }
        }
    }

    // MARK: 定期测量提醒

    private func addGrowth(children: [Child], settings: AppSettings) {
        guard settings.growthReminderOn else { return }
        let cal = Calendar.current
        let step = max(1, settings.growthReminderDays)
        let now = Date()

        for child in children {
            // 基准日：这个宝宝最近一次生长记录；一次都没记过就从今天算起
            let base = child.records.map { $0.date }.max()
            var cursor = cal.startOfDay(for: base ?? now)
            var slot = 0
            var guardCount = 0

            while slot < Self.growthSlots && guardCount < 400 {
                guardCount += 1
                guard let day = cal.date(byAdding: .day, value: step, to: cursor) else { break }
                cursor = day

                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = settings.growthReminderHour
                comps.minute = settings.growthReminderMinute
                guard let fire = cal.date(from: comps) else { continue }
                if fire <= now { continue }          // 已经过去的周期直接跳过

                let days = cal.dateComponents([.day], from: cal.startOfDay(for: base ?? now), to: day).day ?? step
                let content = UNMutableNotificationContent()
                content.title = "该给\(child.name)量身高体重了"
                content.body = "离上次测量 \(days) 天啦。脱鞋靠墙站直量一次，生长曲线才连得上。"
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let id = growthPrefix + child.id.uuidString + "." + String(slot)
                let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(req, withCompletionHandler: { err in
                    if let err = err { AppLog.e("Notify", "排量身高提醒失败：\(err)") }
                })
                slot += 1
            }
        }
    }

    // MARK: 待办到期提醒

    private func addTodos(children: [Child], settings: AppSettings) {
        guard settings.todoReminderOn else { return }
        let cal = Calendar.current
        let now = Date()

        // 只排未完成、有截止日期的；按截止时间由近到远
        var jobs: [(child: Child, todo: TodoItem)] = []
        let muted = settings.mutedTodoReminders
        for child in children {
            for todo in child.todos where !todo.done && todo.due != nil && !muted.contains(todo.id.uuidString) {
                jobs.append((child, todo))
            }
        }
        jobs.sort { ($0.todo.due ?? .distantFuture) < ($1.todo.due ?? .distantFuture) }

        var count = 0
        for job in jobs {
            guard count < Self.todoLimit, let due = job.todo.due else { break }
            let day = cal.startOfDay(for: due)
            let baseID = todoPrefix + job.todo.id.uuidString

            // ① 前一天 20:00 预告
            if let eveDay = cal.date(byAdding: .day, value: -1, to: day),
               let eve = cal.date(bySettingHour: 20, minute: 0, second: 0, of: eveDay),
               eve > now {
                let c = UNMutableNotificationContent()
                c.title = "明天到期：\(job.todo.title)"
                c.body = "\(job.child.name)的待办，明天就到期了，提前安排一下。"
                c.sound = .default
                let ts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: eve)
                let req = UNNotificationRequest(identifier: baseID + ".pre",
                                                content: c,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: ts, repeats: false))
                center.add(req, withCompletionHandler: nil)
            }

            // ② 当天 9:00 提醒
            if let fire = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day), fire > now {
                let c = UNMutableNotificationContent()
                c.title = "今天到期：\(job.todo.title)"
                c.body = "别忘了，做完在待办清单里打个勾。"
                c.sound = .default
                let ts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let req = UNNotificationRequest(identifier: baseID + ".due",
                                                content: c,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: ts, repeats: false))
                center.add(req, withCompletionHandler: nil)
            }
            count += 1
        }
    }

    // MARK: 调试

    /// 把排好的提醒写进运行日志（「我的 → 运行日志」里能看到）
    private func debugList() {
        center.getPendingNotificationRequests { pending in
            let mine = pending.filter { $0.identifier.hasPrefix(self.growthPrefix) || $0.identifier.hasPrefix(self.todoPrefix) }
            guard !mine.isEmpty else { return }
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "zh_CN")
            fmt.dateFormat = "M/d HH:mm"
            let lines = mine.prefix(12).map { req -> String in
                if let t = req.trigger as? UNCalendarNotificationTrigger,
                   let d = t.nextTriggerDate() {
                    return "\(fmt.string(from: d)) \(req.content.title)"
                }
                return req.content.title
            }
            AppLog.i("Notify", "已排 \(mine.count) 条提醒：" + lines.joined(separator: " | "))
        }
    }
}

// MARK: - 前台也能看到横幅

/// 不加 delegate 的话，App 在前台时通知默认不显示，容易让人以为「没提醒」
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
