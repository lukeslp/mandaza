import Foundation

public struct TimeChannels: Equatable, Sendable {
    public let hour: Int
    public let fiveMinuteGroups: Int
    public let remainingMinutes: Int
    public let minute: Int

    public init(date: Date, calendar: Calendar = .current) {
        let rawHour = calendar.component(.hour, from: date) % 12
        hour = rawHour == 0 ? 12 : rawHour
        minute = calendar.component(.minute, from: date)
        fiveMinuteGroups = minute / 5
        remainingMinutes = minute % 5
    }

    public var hourProgress: Double { Double(hour) / 12 }
    public var groupProgress: Double { Double(fiveMinuteGroups) / 12 }
    public var minuteProgress: Double { Double(remainingMinutes) / 5 }

    public var spokenDescription: String {
        "\(hour) hours, \(fiveMinuteGroups) five-minute groups, \(remainingMinutes) individual minutes"
    }
}

public enum TimePulseStrength: Equatable, Sendable {
    case strong
    case medium
    case light
}

public struct TimePulse: Equatable, Sendable {
    public let strength: TimePulseStrength
    public let delayAfter: TimeInterval

    public init(strength: TimePulseStrength, delayAfter: TimeInterval) {
        self.strength = strength
        self.delayAfter = delayAfter
    }
}

public enum TimePulsePattern {
    /// A bounded, readable phrase: hours, five-minute groups, then remainder.
    /// Long counts are split into groups of four by a slightly longer pause.
    public static func make(channels: TimeChannels,
                            exactMinutes: Bool,
                            tempo: TimeInterval) -> [TimePulse] {
        let beat = min(max(tempo, 0.12), 0.6)
        var pulses: [TimePulse] = []
        append(count: channels.hour, strength: .strong, beat: beat, to: &pulses)
        if channels.fiveMinuteGroups > 0 {
            pulses[pulses.count - 1] = TimePulse(strength: pulses.last!.strength,
                                                 delayAfter: beat * 2.5)
            append(count: channels.fiveMinuteGroups, strength: .medium, beat: beat, to: &pulses)
        }
        if exactMinutes, channels.remainingMinutes > 0 {
            pulses[pulses.count - 1] = TimePulse(strength: pulses.last!.strength,
                                                 delayAfter: beat * 2.5)
            append(count: channels.remainingMinutes, strength: .light, beat: beat, to: &pulses)
        }
        if !pulses.isEmpty {
            pulses[pulses.count - 1] = TimePulse(strength: pulses.last!.strength, delayAfter: 0)
        }
        return pulses
    }

    private static func append(count: Int,
                               strength: TimePulseStrength,
                               beat: TimeInterval,
                               to pulses: inout [TimePulse]) {
        guard count > 0 else { return }
        for index in 0..<count {
            let groupingPause = index > 0 && (index + 1) % 4 == 0
            pulses.append(TimePulse(strength: strength,
                                    delayAfter: groupingPause ? beat * 1.6 : beat))
        }
    }
}
