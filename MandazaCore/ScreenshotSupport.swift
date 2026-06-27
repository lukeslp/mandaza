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
}
