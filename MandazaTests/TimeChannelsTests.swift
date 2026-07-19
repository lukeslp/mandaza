import XCTest
@testable import Mandaza

final class TimeChannelsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 18,
                                           hour: hour, minute: minute))!
    }

    func testChannelsAtMidnight() {
        let channels = TimeChannels(date: date(hour: 0, minute: 0), calendar: calendar)
        XCTAssertEqual(channels.hour, 12)
        XCTAssertEqual(channels.fiveMinuteGroups, 0)
        XCTAssertEqual(channels.remainingMinutes, 0)
        XCTAssertEqual(channels.hourProgress, 1, accuracy: 0.0001)
    }

    func testChannelsAtEndOfHour() {
        let channels = TimeChannels(date: date(hour: 23, minute: 59), calendar: calendar)
        XCTAssertEqual(channels.hour, 11)
        XCTAssertEqual(channels.fiveMinuteGroups, 11)
        XCTAssertEqual(channels.remainingMinutes, 4)
        XCTAssertEqual(channels.groupProgress, 11.0 / 12.0, accuracy: 0.0001)
        XCTAssertEqual(channels.minuteProgress, 0.8, accuracy: 0.0001)
    }

    func testPulsePatternLayersStrengths() {
        let channels = TimeChannels(date: date(hour: 2, minute: 17), calendar: calendar)
        let pulses = TimePulsePattern.make(channels: channels, exactMinutes: true, tempo: 0.2)
        XCTAssertEqual(pulses.filter { $0.strength == .strong }.count, 2)
        XCTAssertEqual(pulses.filter { $0.strength == .medium }.count, 3)
        XCTAssertEqual(pulses.filter { $0.strength == .light }.count, 2)
        XCTAssertEqual(pulses.last?.delayAfter, 0)
    }

    func testPulsePatternCanOmitExactMinutesAndClampsTempo() {
        let channels = TimeChannels(date: date(hour: 1, minute: 4), calendar: calendar)
        let pulses = TimePulsePattern.make(channels: channels, exactMinutes: false, tempo: 0.01)
        XCTAssertEqual(pulses.count, 1)
        XCTAssertEqual(pulses.first?.strength, .strong)
        XCTAssertEqual(pulses.first?.delayAfter, 0)
    }
}
