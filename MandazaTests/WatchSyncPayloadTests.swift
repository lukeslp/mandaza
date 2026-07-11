// File Purpose: Verifies plist-safe iPhone-to-Watch settings and snapshot
// payload compatibility, partial updates, and version guards.
// Primary Components: WatchSyncPayloadTests.
// I/O: Mutates and restores shared settings around each test; asserts encoded
// dictionaries round-trip every advertised Watch field.

import XCTest
@testable import Mandaza

@MainActor
final class WatchSyncPayloadTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var settings: MandazaSettings!

    override func setUp() {
        super.setUp()
        suiteName = "Mandaza.WatchSyncTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settings = MandazaSettings(defaults: defaults, migrate: false)
    }

    override func tearDown() {
        settings = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Settings context round trip

    func testSettingsContextRoundTripRestoresEverySyncedKey() {
        let s = settings!
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
        let s = settings!
        s.paletteId = "aurora"
        var context = WatchSync.settingsContext(from: s)
        context.removeValue(forKey: "v")
        s.paletteId = "ember"
        XCTAssertFalse(WatchSync.applySettingsContext(context, to: s))
        XCTAssertEqual(s.paletteId, "ember")
    }

    func testApplySettingsContextRejectsFutureVersion() {
        let s = settings!
        s.drawSpeed = 0.33
        var context = WatchSync.settingsContext(from: s)
        context["v"] = 999
        s.drawSpeed = 0.9
        XCTAssertFalse(WatchSync.applySettingsContext(context, to: s))
        XCTAssertEqual(s.drawSpeed, 0.9, accuracy: 0.0001)
    }

    // MARK: - Partial payload

    func testPartialPayloadAppliesOnlyProvidedKeys() {
        let s = settings!
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
