import Foundation

/// Test/screenshot support. Inert in release builds — `palette(_:)` returns its
/// argument unchanged unless the `MANDAZA_PALETTE` environment variable is set
/// in a DEBUG build (used to pin a palette per launch when capturing App Store
/// screenshots: `SIMCTL_CHILD_MANDAZA_PALETTE=<id> xcrun simctl launch …`).
public enum MandazaScreenshot {
    public static func palette(_ current: String) -> String {
        #if DEBUG
        if let pinned = ProcessInfo.processInfo.environment["MANDAZA_PALETTE"],
           Palette.all.contains(where: { $0.id == pinned }) {
            return pinned
        }
        #endif
        return current
    }

    /// Whether to drive Music Mode's live indicator from a synthetic demo
    /// signal instead of the microphone — set `MANDAZA_MUSIC_DEMO=1` when
    /// capturing App Store screenshots so the shot is reproducible.
    public static var isMusicDemoActive: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["MANDAZA_MUSIC_DEMO"] == "1"
        #else
        return false
        #endif
    }

    /// Pin the Zen clock form for a capture: `MANDAZA_CLOCK_FORM=stacked|editorial|digital`.
    /// Inert in release and when unset/invalid.
    public static func clockForm(_ current: ZenClockForm) -> ZenClockForm {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["MANDAZA_CLOCK_FORM"],
           let pinned = ZenClockForm(rawValue: raw) {
            return pinned
        }
        #endif
        return current
    }

    /// Pin the Zen clock position for a capture: `MANDAZA_CLOCK_POSITION=center|upperThird|…`.
    public static func clockPosition(_ current: ZenClockPosition) -> ZenClockPosition {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["MANDAZA_CLOCK_POSITION"],
           let pinned = ZenClockPosition(rawValue: raw) {
            return pinned
        }
        #endif
        return current
    }
}
