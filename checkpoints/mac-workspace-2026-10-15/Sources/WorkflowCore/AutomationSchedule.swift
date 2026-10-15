import Foundation

public enum AutomationSchedule {
    public static func isDue(_ rule: AutomationRule, now: Date, appStartedAt: Date, calendar: Calendar = .current) -> Bool {
        guard rule.isEnabled, rule.trigger == "time", (0...23).contains(rule.hour), (0...59).contains(rule.minute),
              let scheduled = calendar.date(bySettingHour: rule.hour, minute: rule.minute, second: 0, of: now),
              scheduled >= appStartedAt, now >= scheduled, now.timeIntervalSince(scheduled) < 60 else { return false }
        if let days = rule.weekdays, !days.contains(calendar.component(.weekday, from: now)) { return false }
        return rule.lastFired.map { !calendar.isDate($0, inSameDayAs: now) } ?? true
    }
}
