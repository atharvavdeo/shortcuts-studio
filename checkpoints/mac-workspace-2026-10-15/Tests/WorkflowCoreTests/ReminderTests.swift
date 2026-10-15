import Foundation
import Testing
@testable import WorkflowCore
struct ReminderTests {
    @Test func explicitReminders() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        let now = ISO8601DateFormatter().date(from: "2026-10-14T05:00:00Z")!
        let once = try #require(try ReminderRequest.parse("today at 11am send Good Morning! Lets rock this day", now: now, calendar: calendar))
        #expect(!once.repeats)
        #expect(once.message == "Good Morning! Lets rock this day")
        #expect(once.hour == 11 && once.minute == 0)
        let daily = try #require(try ReminderRequest.parse("everyday morning 10am send a Good Morning! Lets rock this day message", now: now, calendar: calendar))
        #expect(daily.repeats)
        #expect(calendar.component(.day, from: daily.date) == 15)
        #expect(daily.message == once.message)
        #expect(try ReminderRequest.parse("list folder Documents", now: now, calendar: calendar) == nil)
        #expect(throws: (any Error).self) { try ReminderRequest.parse("today at 10am send hello", now: now, calendar: calendar) }
        #expect(throws: (any Error).self) { try ReminderRequest.parse("today at 13am send hello", now: now, calendar: calendar) }
    }
}
