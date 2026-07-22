import Foundation

/// Persisted engagement inputs used to decide whether a system review request
/// is timely. StoreKit still makes the final decision about showing a prompt.
public struct ReviewPromptState: Equatable, Sendable {
    public var firstUseDate: Date?
    public var sessionCount: Int
    public var meaningfulEventCount: Int
    public var lastRequestDate: Date?
    public var lastRequestedVersion: String?

    public init(firstUseDate: Date? = nil,
                sessionCount: Int = 0,
                meaningfulEventCount: Int = 0,
                lastRequestDate: Date? = nil,
                lastRequestedVersion: String? = nil) {
        self.firstUseDate = firstUseDate
        self.sessionCount = sessionCount
        self.meaningfulEventCount = meaningfulEventCount
        self.lastRequestDate = lastRequestDate
        self.lastRequestedVersion = lastRequestedVersion
    }
}

public struct ReviewPromptRequirements: Equatable, Sendable {
    public let minimumSessions: Int
    public let minimumUseAge: TimeInterval
    public let minimumMeaningfulEvents: Int
    public let requestCooldown: TimeInterval

    public init(minimumSessions: Int,
                minimumUseAge: TimeInterval,
                minimumMeaningfulEvents: Int,
                requestCooldown: TimeInterval) {
        self.minimumSessions = minimumSessions
        self.minimumUseAge = minimumUseAge
        self.minimumMeaningfulEvents = minimumMeaningfulEvents
        self.requestCooldown = requestCooldown
    }

    /// Successful image saves are a strong completion signal on iPhone/iPad.
    public static let imageExport = ReviewPromptRequirements(
        minimumSessions: 3,
        minimumUseAge: 7 * 24 * 60 * 60,
        minimumMeaningfulEvents: 2,
        requestCooldown: 120 * 24 * 60 * 60
    )
}

public enum ReviewPromptPolicy {
    public static func shouldRequest(state: ReviewPromptState,
                                     requirements: ReviewPromptRequirements,
                                     now: Date,
                                     appVersion: String) -> Bool {
        guard !appVersion.isEmpty,
              let firstUseDate = state.firstUseDate,
              state.sessionCount >= requirements.minimumSessions,
              state.meaningfulEventCount >= requirements.minimumMeaningfulEvents,
              now.timeIntervalSince(firstUseDate) >= requirements.minimumUseAge,
              state.lastRequestedVersion != appVersion else {
            return false
        }

        if let lastRequestDate = state.lastRequestDate,
           now.timeIntervalSince(lastRequestDate) < requirements.requestCooldown {
            return false
        }
        return true
    }
}

/// Small UserDefaults-backed counter. It stores no account or analytics data;
/// all state stays on the device and exists only to avoid intrusive prompts.
@MainActor
public final class ReviewPromptTracker {
    private enum Key {
        static let firstUse = "reviewPrompt.firstUse"
        static let sessions = "reviewPrompt.sessions"
        static let meaningfulEvents = "reviewPrompt.meaningfulEvents"
        static let lastSession = "reviewPrompt.lastSession"
        static let lastRequest = "reviewPrompt.lastRequest"
        static let lastVersion = "reviewPrompt.lastVersion"
    }

    private static let sessionSeparation: TimeInterval = 6 * 60 * 60
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func recordSession(now: Date = .now) {
        let lastSession = defaults.object(forKey: Key.lastSession) as? Date
        if let lastSession,
           now.timeIntervalSince(lastSession) < Self.sessionSeparation {
            return
        }
        if defaults.object(forKey: Key.firstUse) == nil {
            defaults.set(now, forKey: Key.firstUse)
        }
        defaults.set(defaults.integer(forKey: Key.sessions) + 1, forKey: Key.sessions)
        defaults.set(now, forKey: Key.lastSession)
    }

    public func recordMeaningfulEvent() {
        defaults.set(defaults.integer(forKey: Key.meaningfulEvents) + 1,
                     forKey: Key.meaningfulEvents)
    }

    public func shouldRequest(requirements: ReviewPromptRequirements,
                              now: Date = .now,
                              appVersion: String) -> Bool {
        ReviewPromptPolicy.shouldRequest(
            state: state,
            requirements: requirements,
            now: now,
            appVersion: appVersion
        )
    }

    public func markRequest(now: Date = .now, appVersion: String) {
        defaults.set(now, forKey: Key.lastRequest)
        defaults.set(appVersion, forKey: Key.lastVersion)
    }

    public var state: ReviewPromptState {
        ReviewPromptState(
            firstUseDate: defaults.object(forKey: Key.firstUse) as? Date,
            sessionCount: defaults.integer(forKey: Key.sessions),
            meaningfulEventCount: defaults.integer(forKey: Key.meaningfulEvents),
            lastRequestDate: defaults.object(forKey: Key.lastRequest) as? Date,
            lastRequestedVersion: defaults.string(forKey: Key.lastVersion)
        )
    }
}
