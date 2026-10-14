import Foundation

/// Explicit local reminders are parsed without model inference.
public struct ReminderRequest: Equatable, Sendable {
    public let message: String
    public let hour: Int
    public let minute: Int
    public let repeats: Bool
    public let date: Date
    public static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) throws -> ReminderRequest? {
        let lower = input.lowercased()
        let daily = lower.contains("everyday") || lower.contains("every day") || lower.contains("daily")
        let today = lower.contains("today")
        guard daily || today, lower.contains("send ") || lower.contains("remind ") || lower.contains("notify ") else { return nil }
        let pattern = #"(?i)\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b.*?\b(?:send|remind|notify)\s+(?:me\s+)?(?:a\s+)?(.+)$"#
        let regex = try NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              let hRange = Range(match.range(at: 1), in: input), let aRange = Range(match.range(at: 3), in: input), let textRange = Range(match.range(at: 4), in: input), let rawHour = Int(input[hRange]), (1...12).contains(rawHour) else {
            throw StudioError.message("Use: today at 11am send Good Morning! or every day at 10am send Good Morning! Include AM or PM.")
        }
        let minute = Range(match.range(at: 2), in: input).flatMap { Int(input[$0]) } ?? 0
        guard (0...59).contains(minute) else { throw StudioError.message("Reminder minutes must be 00–59.") }
        let hour = rawHour % 12 + (input[aRange].lowercased() == "pm" ? 12 : 0)
        var message = String(input[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        if message.lowercased().hasSuffix(" message") { message = String(message.dropLast(8)) }
        message = message.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !message.isEmpty, message.utf8.count <= 1000 else { throw StudioError.message("Use a reminder message of 1–1,000 bytes.") }
        guard let scheduled = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { throw StudioError.message("Invalid reminder time.") }
        let repeats = daily && !today
        if !repeats && scheduled <= now { throw StudioError.message("Today's reminder time has passed. Choose a later time; no reminder was scheduled.") }
        let date = scheduled > now ? scheduled : calendar.date(byAdding: .day, value: 1, to: scheduled)!
        return ReminderRequest(message: message, hour: hour, minute: minute, repeats: repeats, date: date)
    }
}
