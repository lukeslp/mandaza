import Foundation
import Observation

public enum ZenClockFontStyle: String, CaseIterable, Codable, Sendable {
    case system
    case rounded
    case monospaced
}

public enum ZenClockPosition: String, CaseIterable, Codable, Sendable {
    case top
    case upperThird
    case center
}

/// Single source of truth for user-editable state, shared between the app
/// and the widget extension via an App Group `UserDefaults` suite.
///
/// Plain `var` properties with `didSet` write-through so the @Observable
/// macro tracks every read site (SwiftUI re-renders when a property changes).
@MainActor
@Observable
public final class MandazaSettings {

    public static let suiteName = "group.com.lukesteuber.mandaza"
    public static let shared = MandazaSettings()

    @ObservationIgnored
    private let defaults: UserDefaults

    // MARK: - Look

    public var paletteId: String       { didSet { write(paletteId, .paletteId) } }
    public var drawSpeed: Double       { didSet { write(drawSpeed, .drawSpeed) } }
    public var lineWidth: Double       { didSet { write(lineWidth, .lineWidth) } }
    public var glow: Bool              { didSet { write(glow, .glow) } }
    /// When `glow` is true, scales shadow blur (stored 0.18…1). Random New may pick a soft band; turning Glow on in settings sets 1.0.
    public var glowStrength: Double    { didSet { write(glowStrength, .glowStrength) } }

    // MARK: - Density / geometry (new in Phase B)

    /// 0…1 — bigger = smaller, denser cells. Default 0.5 = mid-density.
    public var density: Double         { didSet { write(density, .density) } }
    /// "auto" or "sparse" / "medium" / "dense" / "busy" — preset names that
    /// map onto the engine's `geometry` index.
    public var geometryPreset: String  { didSet { write(geometryPreset, .geometryPreset) } }
    public var randomizePaletteOnRegenerate: Bool { didSet { write(randomizePaletteOnRegenerate, .randomizePaletteOnRegenerate) } }

    // MARK: - Zen mode

    public var zenMode: Bool              { didSet { write(zenMode, .zenMode) } }
    public var zenShowClock: Bool         { didSet { write(zenShowClock, .zenShowClock) } }
    public var zenShowSeconds: Bool       { didSet { write(zenShowSeconds, .zenShowSeconds) } }
    public var zenShowDate: Bool          { didSet { write(zenShowDate, .zenShowDate) } }
    public var zenAutoRegen: Bool         { didSet { write(zenAutoRegen, .zenAutoRegen) } }
    public var zenAutoRegenSeconds: Double { didSet { write(zenAutoRegenSeconds, .zenAutoRegenSeconds) } }
    public var zenClockOpacity: Double { didSet { write(zenClockOpacity, .zenClockOpacity) } }
    public var zenClockContainerOpacity: Double { didSet { write(zenClockContainerOpacity, .zenClockContainerOpacity) } }
    public var zenClockFontStyleRaw: String { didSet { write(zenClockFontStyleRaw, .zenClockFontStyleRaw) } }
    public var zenClockFontWeight: Double { didSet { write(zenClockFontWeight, .zenClockFontWeight) } }
    public var zenClockPositionRaw: String { didSet { write(zenClockPositionRaw, .zenClockPositionRaw) } }

    // MARK: - Favorites

    public var favorites: [MandazaSnapshot] { didSet { writeJSON(favorites, .favorites) } }

    // MARK: - Widget rotation

    /// Minutes between widget rotations when "Auto-rotate" is on.
    public var widgetRotationMinutes: Int { didSet { write(widgetRotationMinutes, .widgetRotationMinutes) } }

    // MARK: - Init

    private init() {
        let suite = Self.makeDefaults()
        self.defaults = suite

        // Migration: copy values from .standard suite to App Group on first
        // post-upgrade launch (Phase A note from the architect).
        if suite.object(forKey: Key.paletteId.rawValue) == nil {
            Self.migrateFromStandardSuite(into: suite)
        }

        // Hydrate stored properties from defaults with sensible fallbacks.
        self.paletteId       = suite.string(forKey: Key.paletteId.rawValue) ?? Palette.all.first?.id ?? "aurora"
        self.drawSpeed       = Self.readDouble(suite, .drawSpeed, default: 0.707)
        self.lineWidth       = Self.readDouble(suite, .lineWidth, default: 1.2)
        self.glow            = Self.readBool(suite, .glow, default: false)
        self.glowStrength    = Self.readDouble(suite, .glowStrength, default: 1.0)

        self.density         = Self.readDouble(suite, .density, default: 0.5)
        self.geometryPreset  = suite.string(forKey: Key.geometryPreset.rawValue) ?? "auto"
        self.randomizePaletteOnRegenerate = Self.readBool(suite, .randomizePaletteOnRegenerate, default: true)

        self.zenMode             = Self.readBool(suite, .zenMode, default: false)
        self.zenShowClock        = Self.readBool(suite, .zenShowClock, default: true)
        self.zenShowSeconds      = Self.readBool(suite, .zenShowSeconds, default: false)
        self.zenShowDate         = Self.readBool(suite, .zenShowDate, default: true)
        self.zenAutoRegen        = Self.readBool(suite, .zenAutoRegen, default: true)
        self.zenAutoRegenSeconds = Self.readDouble(suite, .zenAutoRegenSeconds, default: 6)
        self.zenClockOpacity = Self.readDouble(suite, .zenClockOpacity, default: 1.0)
        self.zenClockContainerOpacity = Self.readDouble(suite, .zenClockContainerOpacity, default: 0.0)
        self.zenClockFontStyleRaw = suite.string(forKey: Key.zenClockFontStyleRaw.rawValue) ?? ZenClockFontStyle.system.rawValue
        self.zenClockFontWeight = Self.readDouble(suite, .zenClockFontWeight, default: 0.1)
        self.zenClockPositionRaw = suite.string(forKey: Key.zenClockPositionRaw.rawValue) ?? ZenClockPosition.upperThird.rawValue

        self.widgetRotationMinutes = Self.readInt(suite, .widgetRotationMinutes, default: 60)

        if let data = suite.data(forKey: Key.favorites.rawValue),
           let list = try? JSONDecoder().decode([MandazaSnapshot].self, from: data) {
            self.favorites = list
        } else {
            self.favorites = []
        }
    }

    // MARK: - Derived

    /// Produce an `EngineConfig` from the current settings (used by both the
    /// app's live canvas and the widget snapshot pipeline).
    public func engineConfig() -> EngineConfig {
        var c = EngineConfig()
        c.drawSpeed = drawSpeed
        c.lineWidth = lineWidth
        c.glow = glow
        c.glowStrength = glow ? glowStrength : nil

        // Density slider → cellSize (engine inverts: smaller cellSize = bigger cells).
        c.cellSizeRandom = false
        c.cellSize = max(0.05, min(1.0, 1.0 - density))

        // Geometry preset → engine geometry index (0…6 in tbRelProbaNbPoints).
        switch geometryPreset {
        case "sparse": c.randomPattern = false; c.geometry = 0
        case "medium": c.randomPattern = false; c.geometry = 1
        case "dense":  c.randomPattern = false; c.geometry = 5
        case "busy":   c.randomPattern = false; c.geometry = 6
        default:       c.randomPattern = true
        }
        return c
    }

    /// Toggle a snapshot in favorites. Returns the new favorite state.
    @discardableResult
    public func toggleFavorite(seed: String, paletteId: String, config: EngineConfig) -> Bool {
        if let i = favorites.firstIndex(where: { $0.seed == seed }) {
            favorites.remove(at: i)
            return false
        }
        let snap = MandazaSnapshot(seed: seed, paletteId: paletteId, config: config)
        favorites.insert(snap, at: 0)
        // Cap at 50 to bound App Group plist size.
        if favorites.count > 50 { favorites = Array(favorites.prefix(50)) }
        return true
    }

    public func isFavorite(seed: String) -> Bool {
        favorites.contains(where: { $0.seed == seed })
    }

    /// Randomizes the core pattern controls used by "New" so each generation
    /// can materially differ in structure, density, and stroke behavior.
    public func randomizePatternLook(includePalette: Bool) {
        if includePalette {
            paletteId = Palette.all.filter { $0.id != paletteId }
                .randomElement()?.id ?? paletteId
        }
        density = Double.random(in: 0.12 ... 0.92)
        drawSpeed = Double.random(in: 0.18 ... 1.0)
        lineWidth = Double.random(in: 0.65 ... 2.8)
        geometryPreset = ["auto", "sparse", "medium", "dense", "busy"].randomElement() ?? "auto"
        // Glow defaults off; on randomize, enable softly < half the time.
        if Double.random(in: 0..<1) < 0.42 {
            glow = true
            glowStrength = Double.random(in: 0.34 ... 0.58)
        } else {
            glow = false
            glowStrength = 1.0
        }
    }

    /// Applies density, geometry, and stroke look from a frozen snapshot so
    /// favorites / recents reproduce the saved artwork (not just seed + palette).
    public func applyLook(from config: EngineConfig) {
        drawSpeed = config.drawSpeed
        lineWidth = config.lineWidth
        glow = config.glow
        glowStrength = min(max(config.glowStrength ?? 1.0, 0.18), 1.0)
        density = max(0.0, min(1.0, 1.0 - config.cellSize))
        if config.randomPattern {
            geometryPreset = "auto"
        } else {
            switch config.geometry {
            case 0: geometryPreset = "sparse"
            case 1: geometryPreset = "medium"
            case 5: geometryPreset = "dense"
            case 6: geometryPreset = "busy"
            default: geometryPreset = "auto"
            }
        }
    }

    public var zenClockFontStyle: ZenClockFontStyle {
        get { ZenClockFontStyle(rawValue: zenClockFontStyleRaw) ?? .system }
        set { zenClockFontStyleRaw = newValue.rawValue }
    }

    public var zenClockPosition: ZenClockPosition {
        get { ZenClockPosition(rawValue: zenClockPositionRaw) ?? .upperThird }
        set { zenClockPositionRaw = newValue.rawValue }
    }

    // MARK: - Storage primitives

    private enum Key: String, CaseIterable {
        case paletteId, drawSpeed, lineWidth, glow, glowStrength
        case density, geometryPreset, randomizePaletteOnRegenerate
        case zenMode, zenShowClock, zenShowSeconds, zenShowDate
        case zenAutoRegen, zenAutoRegenSeconds
        case zenClockOpacity, zenClockContainerOpacity
        case zenClockFontStyleRaw, zenClockFontWeight, zenClockPositionRaw
        case favorites
        case widgetRotationMinutes
    }

    private func write<T>(_ value: T, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    private func writeJSON<T: Encodable>(_ value: T, _ key: Key) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key.rawValue)
        }
    }

    private static func readDouble(_ d: UserDefaults, _ key: Key, default fallback: Double) -> Double {
        d.object(forKey: key.rawValue) != nil ? d.double(forKey: key.rawValue) : fallback
    }
    private static func readBool(_ d: UserDefaults, _ key: Key, default fallback: Bool) -> Bool {
        d.object(forKey: key.rawValue) != nil ? d.bool(forKey: key.rawValue) : fallback
    }
    private static func readInt(_ d: UserDefaults, _ key: Key, default fallback: Int) -> Int {
        d.object(forKey: key.rawValue) != nil ? d.integer(forKey: key.rawValue) : fallback
    }

    private static func migrateFromStandardSuite(into target: UserDefaults) {
        let standard = UserDefaults.standard
        for key in Key.allCases {
            if let v = standard.object(forKey: key.rawValue) {
                target.set(v, forKey: key.rawValue)
            }
        }
    }

    private static func makeDefaults() -> UserDefaults {
        #if os(tvOS)
        // tvOS does not share settings with widgets; avoid App Group lookups.
        return .standard
        #else
        // In non-entitled helper/test processes, opening a group suite can emit
        // CFPrefs warnings. Only use group defaults when the App Group container
        // is resolvable for this process.
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) != nil,
              let suite = UserDefaults(suiteName: suiteName) else {
            return .standard
        }
        return suite
        #endif
    }
}

