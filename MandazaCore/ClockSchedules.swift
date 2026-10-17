/*
 File Purpose: Wall-clock-aligned update times for every surface that shows
 the time: the Zen clock overlays (TimelineView) and the widget timelines.

 Primary Components:
 - `ZenClockSchedule` — TimelineSchedule ticking on second or minute boundaries.
 - `ClockTimeline` — minute-boundary entry dates for WidgetKit timelines.

 Inputs / Outputs:
 - Inputs: a start date and whether seconds are shown.
 - Outputs: `Date` sequences whose entries change exactly when the displayed
   second or minute changes.
 */

import Foundation
import SwiftUI

/// Ticks when the displayed time changes. A plain `.periodic(from: .now,
/// by: 30)` schedule renders the entry's own date, so a minute display could
/// keep showing the previous minute for up to 30 seconds after it changed.
public struct ZenClockSchedule: TimelineSchedule {
    public var showSeconds: Bool

    public init(showSeconds: Bool) {
        self.showSeconds = showSeconds
    }

    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        // Low-frequency mode (Always-On) updates at most about once a minute.
        let step: TimeInterval = (showSeconds && mode != .lowFrequency) ? 1 : 60
        var first: Date? = startDate
        var next = ClockTimeline.nextBoundary(after: startDate, step: step)
        return AnyIterator {
            if let date = first {
                first = nil
                return date
            }
            defer { next = next.addingTimeInterval(step) }
            return next
        }
    }
}

/// Entry dates for widget timelines that display the time with
/// `Text(date, style: .time)`, which shows the entry's date and never ticks
/// on its own.
public enum ClockTimeline {
    /// Two hours of minute entries, matching the non-rotating widget timeline.
    public static let minuteEntryCount = 120

    /// `now`, then every following minute boundary, `count` dates in total.
    public static func minuteEntries(from now: Date, count: Int = minuteEntryCount) -> [Date] {
        guard count > 0 else { return [] }
        let firstBoundary = nextBoundary(after: now, step: 60)
        return [now] + (0..<(count - 1)).map { firstBoundary.addingTimeInterval(TimeInterval($0 * 60)) }
    }

    /// The first multiple of `step` seconds strictly after `date`. Every time
    /// zone offset is a whole number of minutes, so minute boundaries in
    /// reference-date seconds are wall-clock minute boundaries everywhere.
    public static func nextBoundary(after date: Date, step: TimeInterval) -> Date {
        let t = date.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (floor(t / step) + 1) * step)
    }
}
