import Foundation

/// Wire codec for phone ↔ watch sync. Pure dictionary/Codable translation —
/// no WatchConnectivity dependency, so it compiles into every target and is
/// unit-testable without a session. Payloads use plist-safe types only
/// (String / Double / Bool / Data); optionals are represented by omission.
public enum WatchSync {

    /// Bump when the payload shape changes incompatibly. A receiver rejects
    /// payloads whose version is missing or newer than its own.
    public static let version = 1

    private enum Key {
        static let version = "v"
        static let sentAt = "sentAt"
        static let type = "type"
        static let settings = "settings"
        static let snapshot = "snapshot"
        static let showSnapshot = "showSnapshot"

        static let paletteId = "paletteId"
        static let drawSpeed = "drawSpeed"
        static let lineWidth = "lineWidth"
        static let glow = "glow"
        static let glowStrength = "glowStrength"
        static let density = "density"
        static let geometryPreset = "geometryPreset"
        static let watchAutoRegen = "watchAutoRegen"
        static let watchAutoRegenSeconds = "watchAutoRegenSeconds"
    }

    // MARK: - Settings context (phone → watch applicationContext)

    /// Encodes the watch-relevant slice of settings as an application-context
    /// dictionary: `["v": 1, "sentAt": <epoch seconds>, "settings": [...]]`.
    @MainActor
    public static func settingsContext(from settings: MandazaSettings) -> [String: Any] {
        let inner: [String: Any] = [
            Key.paletteId: settings.paletteId,
            Key.drawSpeed: settings.drawSpeed,
            Key.lineWidth: settings.lineWidth,
            Key.glow: settings.glow,
            Key.glowStrength: settings.glowStrength,
            Key.density: settings.density,
            Key.geometryPreset: settings.geometryPreset,
            Key.watchAutoRegen: settings.watchAutoRegen,
            Key.watchAutoRegenSeconds: settings.watchAutoRegenSeconds,
        ]
        return [
            Key.version: version,
            Key.sentAt: Date().timeIntervalSince1970,
            Key.settings: inner,
        ]
    }

    /// Applies a received settings context. Returns `false` and applies
    /// nothing when the version key is missing or newer than `version`.
    /// Within a known version each key is applied independently, so
    /// unknown or missing keys are skipped rather than failing the whole
    /// payload.
    @MainActor
    @discardableResult
    public static func applySettingsContext(_ dict: [String: Any], to settings: MandazaSettings) -> Bool {
        guard let v = dict[Key.version] as? Int, v <= version else { return false }
        guard let inner = dict[Key.settings] as? [String: Any] else { return false }

        if let paletteId = inner[Key.paletteId] as? String { settings.paletteId = paletteId }
        if let drawSpeed = inner[Key.drawSpeed] as? Double { settings.drawSpeed = drawSpeed }
        if let lineWidth = inner[Key.lineWidth] as? Double { settings.lineWidth = lineWidth }
        if let glow = inner[Key.glow] as? Bool { settings.glow = glow }
        if let glowStrength = inner[Key.glowStrength] as? Double { settings.glowStrength = glowStrength }
        if let density = inner[Key.density] as? Double { settings.density = density }
        if let geometryPreset = inner[Key.geometryPreset] as? String { settings.geometryPreset = geometryPreset }
        if let watchAutoRegen = inner[Key.watchAutoRegen] as? Bool { settings.watchAutoRegen = watchAutoRegen }
        if let seconds = inner[Key.watchAutoRegenSeconds] as? Double { settings.watchAutoRegenSeconds = seconds }
        return true
    }

    // MARK: - Snapshot message (phone → watch sendMessage)

    /// Wraps a snapshot for immediate transfer:
    /// `["v": 1, "type": "showSnapshot", "snapshot": <JSON Data>]`.
    public static func snapshotMessage(_ snapshot: MandazaSnapshot) -> [String: Any] {
        var message: [String: Any] = [
            Key.version: version,
            Key.type: Key.showSnapshot,
        ]
        if let data = try? JSONEncoder().encode(snapshot) {
            message[Key.snapshot] = data
        }
        return message
    }

    /// Decodes a snapshot message. Returns nil when the version is missing
    /// or newer, the type is not `showSnapshot`, or the payload fails to
    /// decode.
    public static func decodeSnapshot(from dict: [String: Any]) -> MandazaSnapshot? {
        guard let v = dict[Key.version] as? Int, v <= version,
              dict[Key.type] as? String == Key.showSnapshot,
              let data = dict[Key.snapshot] as? Data else { return nil }
        return try? JSONDecoder().decode(MandazaSnapshot.self, from: data)
    }
}
