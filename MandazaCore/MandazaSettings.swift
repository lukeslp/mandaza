import Foundation
import Observation

public enum ZenClockFontStyle: String, CaseIterable, Codable, Sendable {
    case system
    case rounded
    case monospaced
    case serif
    case condensed
}

public enum ZenClockPosition: String, CaseIterable, Codable, Sendable {
    case top
    case upperThird
    case center
    case lowerThird
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

public enum ZenClockForm: String, CaseIterable, Codable, Sendable {
    case digital
    case stacked
    case editorial
}

public enum ZenTiltIntensity: String, CaseIterable, Codable, Sendable {
    case off
    case subtle
    case pronounced
}

/// Which tilt axes drive parallax travel.
public enum ZenTiltAxes: String, CaseIterable, Codable, Sendable {
    case both
    case horizontal
    case vertical
}

/// Live canvas ground + stroke depth language.
///
/// - `void`: deep black with neon glow (default).
/// - `paper`: warm parchment with soft ink shadows — a light-theme stab.
public enum CanvasTheme: String, CaseIterable, Codable, Sendable {
    case void
    case paper
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
    /// True when the user has explicitly disabled glow via the settings toggle.
    /// randomizePatternLook respects this and will not re-enable glow.
    public var glowUserDisabled: Bool  { didSet { write(glowUserDisabled, .glowUserDisabled) } }

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
    /// Multiplier applied to the Zen clock's base point size. Default 1.0.
    public var zenClockSizeScale: Double { didSet { write(zenClockSizeScale, .zenClockSizeScale) } }
    /// Raw value of the Zen clock layout form; use `zenClockForm` for typed access.
    public var zenClockFormRaw: String { didSet { write(zenClockFormRaw, .zenClockFormRaw) } }

    // MARK: - Music responsivity

    /// When true (default on iOS/watchOS), entering Zen starts the audio reactor.
    public var musicResponsivity: Bool { didSet { write(musicResponsivity, .musicResponsivity) } }
    /// 0…1 — how strongly the mandala responds to music. Default 0.35.
    public var reactivity: Double { didSet { write(reactivity, .reactivity) } }

    // MARK: - Tilt

    /// Master parallax switch. When false, motion sampling stops.
    public var zenTiltEnabled: Bool { didSet { write(zenTiltEnabled, .zenTiltEnabled) } }
    /// 0…1 travel strength. 1.0 ≈ 48% of the shorter edge; legacy Subtle ≈ 0.375.
    public var zenTiltAmount: Double { didSet { write(zenTiltAmount, .zenTiltAmount) } }
    /// 0…1 how strongly luminance separates near/far layers. 0 = flat shift.
    public var zenTiltDepth: Double { didSet { write(zenTiltDepth, .zenTiltDepth) } }
    /// When true, darker strokes sit nearer (more travel).
    public var zenTiltInvertDepth: Bool { didSet { write(zenTiltInvertDepth, .zenTiltInvertDepth) } }
    /// Raw value of tilt axes; use `zenTiltAxes` for typed access.
    public var zenTiltAxesRaw: String { didSet { write(zenTiltAxesRaw, .zenTiltAxesRaw) } }
    /// Legacy intensity raw — kept for migration / older readers. Prefer
    /// `zenTiltEnabled` + `zenTiltAmount`.
    public var zenTiltIntensityRaw: String { didSet { write(zenTiltIntensityRaw, .zenTiltIntensityRaw) } }

    // MARK: - Canvas theme

    /// Raw canvas theme; use `canvasTheme` for typed access.
    public var canvasThemeRaw: String { didSet { write(canvasThemeRaw, .canvasThemeRaw) } }

    // MARK: - Favorites

    public var favorites: [MandazaSnapshot] { didSet { writeJSON(favorites, .favorites) } }

    // MARK: - Widget rotation

    /// Minutes between widget rotations when "Auto-rotate" is on.
    public var widgetRotationMinutes: Int { didSet { write(widgetRotationMinutes, .widgetRotationMinutes) } }

    // MARK: - Watch

    public var watchAutoRegen: Bool          { didSet { write(watchAutoRegen, .watchAutoRegen) } }
    public var watchAutoRegenSeconds: Double { didSet { write(watchAutoRegenSeconds, .watchAutoRegenSeconds) } }

    // MARK: - Music mode / pinned snapshot

    public var musicMode: Bool { didSet { write(musicMode, .musicMode) } }
    /// Raw JSON of the pinned snapshot; use `pinnedSnapshot` for typed access.
    public var pinnedSnapshotData: Data? { didSet { writeData(pinnedSnapshotData, .pinnedSnapshotData) } }

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
        self.glowUserDisabled = Self.readBool(suite, .glowUserDisabled, default: true)

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
        self.zenClockSizeScale = Self.readDouble(suite, .zenClockSizeScale, default: 1.0)
        self.zenClockFormRaw = suite.string(forKey: Key.zenClockFormRaw.rawValue) ?? ZenClockForm.digital.rawValue

        self.musicResponsivity = Self.readBool(suite, .musicResponsivity, default: true)
        self.reactivity = Self.readDouble(suite, .reactivity, default: 0.35)

        let legacyTilt = ZenTiltIntensity(
            rawValue: suite.string(forKey: Key.zenTiltIntensityRaw.rawValue)
                ?? ZenTiltIntensity.subtle.rawValue
        ) ?? .subtle
        self.zenTiltIntensityRaw = legacyTilt.rawValue
        self.zenTiltEnabled = Self.readBool(suite, .zenTiltEnabled, default: legacyTilt != .off)
        if suite.object(forKey: Key.zenTiltAmount.rawValue) == nil {
            // Map legacy presets onto the continuous slider.
            switch legacyTilt {
            case .off:        self.zenTiltAmount = 0.55
            case .subtle:     self.zenTiltAmount = tiltAmount(for: .subtle)
            case .pronounced: self.zenTiltAmount = tiltAmount(for: .pronounced)
            }
        } else {
            self.zenTiltAmount = Self.readDouble(suite, .zenTiltAmount, default: 0.55)
        }
        self.zenTiltDepth = Self.readDouble(suite, .zenTiltDepth, default: 0.85)
        self.zenTiltInvertDepth = Self.readBool(suite, .zenTiltInvertDepth, default: false)
        self.zenTiltAxesRaw = suite.string(forKey: Key.zenTiltAxesRaw.rawValue) ?? ZenTiltAxes.both.rawValue
        self.canvasThemeRaw = suite.string(forKey: Key.canvasThemeRaw.rawValue) ?? CanvasTheme.void.rawValue

        self.widgetRotationMinutes = Self.readInt(suite, .widgetRotationMinutes, default: 60)

        self.watchAutoRegen        = Self.readBool(suite, .watchAutoRegen, default: true)
        self.watchAutoRegenSeconds = Self.readDouble(suite, .watchAutoRegenSeconds, default: 6)
        self.musicMode             = Self.readBool(suite, .musicMode, default: false)
        self.pinnedSnapshotData    = suite.data(forKey: Key.pinnedSnapshotData.rawValue)

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
        // Respect the user's explicit glow preference — never re-enable if they turned it off.
        if !glowUserDisabled {
            if Double.random(in: 0..<1) < 0.42 {
                glow = true
                glowStrength = Double.random(in: 0.34 ... 0.58)
            } else {
                glow = false
                glowStrength = 1.0
            }
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

    public var zenClockForm: ZenClockForm {
        get { ZenClockForm(rawValue: zenClockFormRaw) ?? .digital }
        set { zenClockFormRaw = newValue.rawValue }
    }

    public var zenTiltAxes: ZenTiltAxes {
        get { ZenTiltAxes(rawValue: zenTiltAxesRaw) ?? .both }
        set { zenTiltAxesRaw = newValue.rawValue }
    }

    public var canvasTheme: CanvasTheme {
        get { CanvasTheme(rawValue: canvasThemeRaw) ?? .void }
        set { canvasThemeRaw = newValue.rawValue }
    }

    /// Legacy intensity bridge. Reading synthesizes from enabled + amount;
    /// writing updates enabled/amount so older call sites still work.
    public var zenTiltIntensity: ZenTiltIntensity {
        get {
            guard zenTiltEnabled else { return .off }
            return zenTiltAmount < 0.6 ? .subtle : .pronounced
        }
        set {
            zenTiltIntensityRaw = newValue.rawValue
            switch newValue {
            case .off:
                zenTiltEnabled = false
            case .subtle:
                zenTiltEnabled = true
                zenTiltAmount = tiltAmount(for: .subtle)
            case .pronounced:
                zenTiltEnabled = true
                zenTiltAmount = tiltAmount(for: .pronounced)
            }
        }
    }

    /// Typed accessor over `pinnedSnapshotData` — the snapshot the watch face
    /// keeps showing while auto-regeneration is paused.
    public var pinnedSnapshot: MandazaSnapshot? {
        get {
            guard let data = pinnedSnapshotData else { return nil }
            return try? JSONDecoder().decode(MandazaSnapshot.self, from: data)
        }
        set {
            if let snap = newValue {
                pinnedSnapshotData = try? JSONEncoder().encode(snap)
            } else {
                pinnedSnapshotData = nil
            }
        }
    }

    // MARK: - Storage primitives

    private enum Key: String, CaseIterable {
        case paletteId, drawSpeed, lineWidth, glow, glowStrength, glowUserDisabled
        case density, geometryPreset, randomizePaletteOnRegenerate
        case zenMode, zenShowClock, zenShowSeconds, zenShowDate
        case zenAutoRegen, zenAutoRegenSeconds
        case zenClockOpacity, zenClockContainerOpacity
        case zenClockFontStyleRaw, zenClockFontWeight, zenClockPositionRaw
        case zenClockSizeScale, zenClockFormRaw
        case musicResponsivity, reactivity
        case zenTiltEnabled, zenTiltAmount, zenTiltDepth, zenTiltInvertDepth
        case zenTiltAxesRaw, zenTiltIntensityRaw
        case canvasThemeRaw
        case favorites
        case widgetRotationMinutes
        case watchAutoRegen, watchAutoRegenSeconds
        case musicMode, pinnedSnapshotData
    }

    private func write<T>(_ value: T, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    private func writeJSON<T: Encodable>(_ value: T, _ key: Key) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key.rawValue)
        }
    }

    private func writeData(_ value: Data?, _ key: Key) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
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

