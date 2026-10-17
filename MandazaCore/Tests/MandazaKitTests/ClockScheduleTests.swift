// File Purpose: Verifies that clock surfaces update on wall-clock boundaries.
// Primary Components: ClockScheduleTests.
// I/O: Supplies fixed start dates; asserts Zen clock TimelineSchedule ticks
// and widget minute-entry dates.

import XCTest
import SwiftUI
#if SWIFT_PACKAGE
@testable import MandazaKit
#endif

final class ClockScheduleTests: XCTestCase {

    /// A minute boundary (800_000_040 is a multiple of 60 in reference-date
    /// seconds) plus 17 minutes 42.5 seconds.
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_040 + 17 * 60 + 42.5)

    private func firstEntries(_ schedule: ZenClockSchedule,
                              mode: TimelineScheduleMode = .normal,
                              count: Int) -> [Date] {
        Array(schedule.entries(from: start, mode: mode).prefix(count))
    }

    private func secondsIntoMinute(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60)
    }

    func testMinuteClockRendersNowThenTicksOnEachMinuteBoundary() {
        let dates = firstEntries(ZenClockSchedule(showSeconds: false), count: 4)
        XCTAssertEqual(dates[0], start)
        XCTAssertEqual(dates[1].timeIntervalSince(start), 17.5, accuracy: 1e-6)
        for date in dates.dropFirst() {
            XCTAssertEqual(secondsIntoMinute(date), 0, accuracy: 1e-6)
        }
        XCTAssertEqual(dates[2].timeIntervalSince(dates[1]), 60, accuracy: 1e-6)
        XCTAssertEqual(dates[3].timeIntervalSince(dates[2]), 60, accuracy: 1e-6)
    }

    func testSecondsClockTicksOnWholeSeconds() {
        let dates = firstEntries(ZenClockSchedule(showSeconds: true), count: 4)
        XCTAssertEqual(dates[0], start)
        XCTAssertEqual(dates[1].timeIntervalSince(start), 0.5, accuracy: 1e-6)
        XCTAssertEqual(dates[2].timeIntervalSince(dates[1]), 1, accuracy: 1e-6)
        XCTAssertEqual(dates[3].timeIntervalSince(dates[2]), 1, accuracy: 1e-6)
    }

    func testSecondsClockFallsBackToMinutesInLowFrequencyMode() {
        let dates = firstEntries(ZenClockSchedule(showSeconds: true), mode: .lowFrequency, count: 3)
        XCTAssertEqual(secondsIntoMinute(dates[1]), 0, accuracy: 1e-6)
        XCTAssertEqual(dates[2].timeIntervalSince(dates[1]), 60, accuracy: 1e-6)
    }

    func testWidgetMinuteEntriesStartNowAndAlignToMinutes() {
        let dates = ClockTimeline.minuteEntries(from: start)
        XCTAssertEqual(dates.count, ClockTimeline.minuteEntryCount)
        XCTAssertEqual(dates.first, start)
        XCTAssertEqual(dates[1].timeIntervalSince(start), 17.5, accuracy: 1e-6)
        for (earlier, later) in zip(dates.dropFirst(), dates.dropFirst(2)) {
            XCTAssertEqual(later.timeIntervalSince(earlier), 60, accuracy: 1e-6)
            XCTAssertEqual(secondsIntoMinute(later), 0, accuracy: 1e-6)
        }
    }

    func testStartOnABoundaryDoesNotRepeatThatMinute() {
        let onBoundary = Date(timeIntervalSinceReferenceDate: 800_000_040)
        let dates = ClockTimeline.minuteEntries(from: onBoundary, count: 3)
        XCTAssertEqual(dates[1].timeIntervalSince(onBoundary), 60, accuracy: 1e-6)
    }
}
