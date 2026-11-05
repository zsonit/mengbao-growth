import Foundation
import EventKit

// MARK: - 接种计划同步到系统日历
//
// 把「安排」好的接种计划写成一条日历事件（开始前 1 小时提醒），
// 同一剂同一时间只写一次：本地记录已写入的 key，重复点「同步」不会建重复事件。

enum CalendarSync {

    private static let store = EKEventStore()
    private static let doneKey = "mb.cal.synced"

    private static func syncedSet() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: doneKey) ?? [])
    }

    private static func markSynced(_ key: String) {
        var done = syncedSet()
        done.insert(key)
        UserDefaults.standard.set(Array(done), forKey: doneKey)
    }

    /// 计划的目标时刻（指定了就用指定时刻，否则当天 09:00）
    static func targetDate(_ dose: Dose, _ plan: DosePlan) -> Date {
        if let d = plan.date { return d }
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dose.dueDate) ?? dose.dueDate
    }

    /// 把一剂接种计划写进系统日历；返回错误描述（nil = 成功或已写过）
    static func addDoseEvent(child: Child, dose: Dose, plan: DosePlan,
                             completion: @escaping (String?) -> Void) {
        let target = targetDate(dose, plan)
        let dedupe = "\(child.id).\(dose.key).\(Int(target.timeIntervalSince1970))"
        if syncedSet().contains(dedupe) { completion(nil); return }

        let grant: (Bool) -> Void = { granted in
            guard granted else { completion("没有日历权限：请到 系统设置 → 萌宝成长 → 日历 里允许"); return }
            let event = EKEvent(eventStore: store)
            let extra = Standards.extraByCode[dose.vaccine.code]
            event.title = "接种：\(dose.vaccine.name)（\(dose.vaccine.dose)）· \(child.name)"
            var notes = "萌宝成长 · 接种计划"
            if let p = extra?.prevents { notes += "\n预防：\(p)" }
            notes += "\n接种方式：\(dose.vaccine.route)"
            if let a = extra?.amount { notes += "\n剂量：\(a)" }
            if !plan.place.isEmpty { notes += "\n地点：\(plan.place)" }
            if !plan.note.isEmpty { notes += "\n备注：\(plan.note)" }
            event.notes = notes
            event.startDate = target
            event.endDate = target.addingTimeInterval(3600)
            event.calendar = store.defaultCalendarForNewEvents
            event.alarms = [EKAlarm(relativeOffset: -3600)]
            do {
                try store.save(event, span: .thisEvent)
                markSynced(dedupe)
                completion(nil)
            } catch {
                completion("写入日历失败：\(error.localizedDescription)")
            }
        }

        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, _ in grant(granted) }
        } else {
            store.requestAccess(to: .event) { granted, _ in grant(granted) }
        }
    }
}
