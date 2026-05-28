import Foundation
import Testing
@testable import Core

@Suite("WatchMidnightTimer Tests")
struct WatchMidnightTimerTests {

    @Test("Next firing date is local midnight of the day after `now`")
    func nextFiringDateAfterNow() throws {
        let calendar = Calendar(identifier: .gregorian)

        // 2023-11-14 in UTC; in most timezones this is still 2023-11-14
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let firing = try #require(WatchMidnightTimer.nextMidnight(after: now, calendar: calendar))
        let components = calendar.dateComponents([.hour, .minute, .second, .day], from: firing)

        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)

        let oldDay = calendar.component(.day, from: now)
        let newDay = components.day ?? 0
        #expect(newDay != oldDay)
    }

    @Test("If now is exactly midnight, the next firing is 24 hours later")
    func midnightExact() throws {
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let firing = try #require(WatchMidnightTimer.nextMidnight(after: startOfDay, calendar: calendar))
        let delta = firing.timeIntervalSince(startOfDay)
        #expect(delta > 86_000)
        #expect(delta < 86_500)
    }
}
