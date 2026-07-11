// File Purpose: Verifies plist-safe iPhone-to-Watch settings and snapshot
// payload compatibility, partial updates, and version guards.
// Primary Components: WatchSyncPayloadTests.
// I/O: Mutates and restores shared settings around each test; asserts encoded
// dictionaries round-trip every advertised Watch field.

import XCTest
@testable import Mandaza

@MainActor
final class WatchSyncPayloadTests: XCTestCase {

    private var savedPaletteId = ""
    private var savedDrawSpeed = 0.0
    private var savedLineWidth = 0.0
    private var savedGlow = false
    private var savedGlowStrength = 0.0
    private var savedDensity = 0.0
    private var savedGeometryPreset = ""
    private var savedWatchAutoRegen = false
    private var savedWatchAutoRegenSeconds = 0.0
    private var savedReactivity = 0.0
    private var savedClockFormRaw = ""
    private var savedClockSizeScale = 0.0
    private var savedTiltEnabled = false
    private var savedTiltAmount = 0.0
    private var savedTiltDepth = 0.0
    private var savedTiltInvertDepth = false
    private var savedTiltAxesRaw = ""
    private var savedCanvasThemeRaw = ""

    override func setUp() {
        super.setUp()
        let s = MandazaSettings.shared
        savedPaletteId = s.paletteId
        savedDrawSpeed = s.drawSpeed
        savedLineWidth = s.lineWidth
        savedGlow = s.glow
        savedGlowStrength = s.glowStrength
        savedDensity = s.density
        savedGeometryPreset = s.geometryPreset
        savedWatchAutoRegen = s.watchAutoRegen
        savedWatchAutoRegenSeconds = s.watchAutoRegenSeconds
        savedReactivity = s.reactivity
        savedClockFormRaw = s.zenClockFormRaw
        savedClockSizeScale = s.zenClockSizeScale
        savedTiltEnabled = s.zenTiltEnabled
        savedTiltAmount = s.zenTiltAmount
        savedTiltDepth = s.zenTiltDepth
        savedTiltInvertDepth = s.zenTiltInvertDepth
        savedTiltAxesRaw = s.zenTiltAxesRaw
        savedCanvasThemeRaw = s.canvasThemeRaw
    }

    override func tearDown() {
        let s = MandazaSettings.shared
        s.paletteId = savedPaletteId
        s.drawSpeed = savedDrawSpeed
        s.lineWidth = savedLineWidth
        s.glow = savedGlow
        s.glowStrength = savedGlowStrength
        s.density = savedDensity
        s.geometryPreset = savedGeometryPreset
        s.watchAutoRegen = savedWatchAutoRegen
        s.watchAutoRegenSeconds = savedWatchAutoRegenSeconds
        s.reactivity = savedReactivity
        s.zenClockFormRaw = savedClockFormRaw
        s.zenClockSizeScale = savedClockSizeScale
        s.zenTiltEnabled = savedTiltEnabled
        s.zenTiltAmount = savedTiltAmount
        s.zenTiltDepth = savedTiltDepth
        s.zenTiltInvertDepth = savedTiltInvertDepth
        s.zenTiltAxesRaw = savedTiltAxesRaw
        s.canvasThemeRaw = savedCanvasThemeRaw
        super.tearDown()
    }

    // MARK: - Settings context round trip

    func testSettingsContextRoundTripRestoresEverySyncedKey() {
        let s = MandazaSettings.shared
        s.paletteId = "aurora"
        s.drawSpeed = 0.33
        s.lineWidth = 1.7
        s.glow = true
        s.glowStrength = 0.44
        s.density = 0.66
        s.geometryPreset = "dense"
        s.watchAutoRegen = true
        s.watchAutoRegenSeconds = 45
        s.reactivity = 0.72
        s.zenClockForm = .stacked
        s.zenClockSizeScale = 1.35
        s.zenTiltEnabled = true
        s.zenTiltAmount = 0.64
        s.zenTiltDepth = 0.81
        s.zenTiltInvertDepth = true
        s.zenTiltAxes = .vertical
        s.canvasTheme = .paper

        let context = WatchSync.settingsContext(from: s)

        s.paletteId = "ember"
        s.drawSpeed = 0.9
        s.lineWidth = 0.8
        s.glow = false
        s.glowStrength = 1.0
        s.density = 0.2
        s.geometryPreset = "sparse"
        s.watchAutoRegen = false
        s.watchAutoRegenSeconds = 120
        s.reactivity = 0.1
        s.zenClockForm = .digital
        s.zenClockSizeScale = 0.7
        s.zenTiltEnabled = false
        s.zenTiltAmount = 0.2
        s.zenTiltDepth = 0.1
        s.zenTiltInvertDepth = false
        s.zenTiltAxes = .horizontal
        s.canvasTheme = .void

        XCTAssertTrue(WatchSync.applySettingsContext(context, to: s))
        XCTAssertEqual(s.paletteId, "aurora")
        XCTAssertEqual(s.drawSpeed, 0.33, accuracy: 0.0001)
        XCTAssertEqual(s.lineWidth, 1.7, accuracy: 0.0001)
        XCTAssertTrue(s.glow)
        XCTAssertEqual(s.glowStrength, 0.44, accuracy: 0.0001)
        XCTAssertEqual(s.density, 0.66, accuracy: 0.0001)
        XCTAssertEqual(s.geometryPreset, "dense")
        XCTAssertTrue(s.watchAutoRegen)
        XCTAssertEqual(s.watchAutoRegenSeconds, 45, accuracy: 0.0001)
        XCTAssertEqual(s.reactivity, 0.72, accuracy: 0.0001)
        XCTAssertEqual(s.zenClockForm, .stacked)
        XCTAssertEqual(s.zenClockSizeScale, 1.35, accuracy: 0.0001)
        XCTAssertTrue(s.zenTiltEnabled)
        XCTAssertEqual(s.zenTiltAmount, 0.64, accuracy: 0.0001)
        XCTAssertEqual(s.zenTiltDepth, 0.81, accuracy: 0.0001)
        XCTAssertTrue(s.zenTiltInvertDepth)
        XCTAssertEqual(s.zenTiltAxes, .vertical)
        XCTAssertEqual(s.canvasTheme, .paper)
    }

    // MARK: - Version guards

    func testApplySettingsContextRejectsMissingVersion() {
        let s = MandazaSettings.shared
        s.paletteId = "aurora"
        var context = WatchSync.settingsContext(from: s)
        context.removeValue(forKey: "v")
        s.paletteId = "ember"
        XCTAssertFalse(WatchSync.applySettingsContext(context, to: s))
        XCTAssertEqual(s.paletteId, "ember")
    }

    func testApplySettingsContextRejectsFutureVersion() {
        let s = MandazaSettings.shared
        s.drawSpeed = 0.33
        var context = WatchSync.settingsContext(from: s)
        context["v"] = 999
        s.drawSpeed = 0.9
        XCTAssertFalse(WatchSync.applySettingsContext(context, to: s))
        XCTAssertEqual(s.drawSpeed, 0.9, accuracy: 0.0001)
    }

    // MARK: - Partial payload

    func testPartialPayloadAppliesOnlyProvidedKeys() {
        let s = MandazaSettings.shared
        s.paletteId = "aurora"
        s.drawSpeed = 0.5
        s.lineWidth = 1.2
        let context: [String: Any] = [
            "v": WatchSync.version,
            "settings": ["paletteId": "ember"],
        ]
        XCTAssertTrue(WatchSync.applySettingsContext(context, to: s))
        XCTAssertEqual(s.paletteId, "ember")
        XCTAssertEqual(s.drawSpeed, 0.5, accuracy: 0.0001)
        XCTAssertEqual(s.lineWidth, 1.2, accuracy: 0.0001)
    }

    // MARK: - Snapshot message

    func testSnapshotMessageRoundTripsIncludingLegacyNilGlowStrength() {
        var cfg = EngineConfig()
        cfg.drawSpeed = 0.4
        cfg.lineWidth = 2.1
        cfg.glow = false
        cfg.glowStrength = nil
        cfg.randomPattern = false
        cfg.geometry = 5
        cfg.cellSizeRandom = false
        cfg.cellSize = 0.3
        let snapshot = MandazaSnapshot(seed: "sync-test-seed",
                                       paletteId: "aurora",
                                       config: cfg)

        let message = WatchSync.snapshotMessage(snapshot)
        let decoded = WatchSync.decodeSnapshot(from: message)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.seed, "sync-test-seed")
        XCTAssertEqual(decoded?.paletteId, "aurora")
        XCTAssertNil(decoded?.config.glowStrength)
        XCTAssertEqual(decoded?.config.geometry, 5)
        XCTAssertEqual(decoded?.config.cellSize ?? 0, 0.3, accuracy: 0.0001)
        XCTAssertEqual(decoded?.config.drawSpeed ?? 0, 0.4, accuracy: 0.0001)
    }

    func testDecodeSnapshotRejectsWrongTypeAndCorruptData() {
        let snapshot = MandazaSnapshot(paletteId: "aurora", config: EngineConfig())

        var wrongType = WatchSync.snapshotMessage(snapshot)
        wrongType["type"] = "somethingElse"
        XCTAssertNil(WatchSync.decodeSnapshot(from: wrongType))

        var corrupt = WatchSync.snapshotMessage(snapshot)
        corrupt["snapshot"] = Data("not json".utf8)
        XCTAssertNil(WatchSync.decodeSnapshot(from: corrupt))
    }
}
