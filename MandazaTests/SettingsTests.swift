/*
 File Purpose: Verifies Mandaza settings persistence and EngineConfig mapping.
 Primary Components: SettingsTests with an isolated UserDefaults suite per test.
 Inputs / Outputs: Writes temporary preferences and asserts derived settings,
 favorites, typography, and restored visual configuration.
 */

import XCTest
@testable import Mandaza

@MainActor
final class SettingsTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "MandazaTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeSettings() -> MandazaSettings {
        MandazaSettings(defaults: defaults)
    }

    func testEngineConfigReflectsLookValues() {
        let s = makeSettings()
        s.drawSpeed = 0.8
        s.lineWidth = 2.5
        s.glow = false
        s.glowStrength = 1.0
        var cfg = s.engineConfig()
        XCTAssertEqual(cfg.drawSpeed, 0.8, accuracy: 0.0001)
        XCTAssertEqual(cfg.lineWidth, 2.5, accuracy: 0.0001)
        XCTAssertFalse(cfg.glow)
        XCTAssertNil(cfg.glowStrength)
        s.glow = true
        s.glowStrength = 0.42
        cfg = s.engineConfig()
        XCTAssertTrue(cfg.glow)
        XCTAssertEqual(cfg.glowStrength ?? 0, 0.42, accuracy: 0.0001)
    }

    func testEngineConfigMapsDensityToCellSize() {
        let s = makeSettings()
        s.density = 0.0
        XCTAssertEqual(s.engineConfig().cellSize, 1.0, accuracy: 0.0001)
        s.density = 1.0
        XCTAssertEqual(s.engineConfig().cellSize, 0.05, accuracy: 0.0001)
        s.density = 0.5
        XCTAssertEqual(s.engineConfig().cellSize, 0.5, accuracy: 0.0001)
    }

    func testEngineConfigGeometryPresets() {
        let s = makeSettings()
        s.geometryPreset = "auto"
        XCTAssertTrue(s.engineConfig().randomPattern)
        s.geometryPreset = "sparse"
        XCTAssertFalse(s.engineConfig().randomPattern)
        XCTAssertEqual(s.engineConfig().geometry, 0)
        s.geometryPreset = "busy"
        XCTAssertEqual(s.engineConfig().geometry, 6)
    }

    func testFavoritesToggleAddsAndRemoves() {
        let s = makeSettings()
        s.favorites = []   // clean slate

        let added = s.toggleFavorite(seed: "test-favorite-1",
                                     paletteId: "aurora",
                                     config: EngineConfig())
        XCTAssertTrue(added)
        XCTAssertEqual(s.favorites.count, 1)
        XCTAssertTrue(s.isFavorite(seed: "test-favorite-1"))

        let removed = s.toggleFavorite(seed: "test-favorite-1",
                                       paletteId: "aurora",
                                       config: EngineConfig())
        XCTAssertFalse(removed)
        XCTAssertEqual(s.favorites.count, 0)
        XCTAssertFalse(s.isFavorite(seed: "test-favorite-1"))
    }

    func testFavoritesCappedAt50() {
        let s = makeSettings()
        s.favorites = []
        for i in 0..<60 {
            s.toggleFavorite(seed: "seed-\(i)",
                             paletteId: "aurora",
                             config: EngineConfig())
        }
        XCTAssertEqual(s.favorites.count, 50)
        // Most recent (seed-59) should be at the front.
        XCTAssertEqual(s.favorites.first?.seed, "seed-59")
        s.favorites = []
    }

    func testZenClockTypographyWeightLabelMatchesBuckets() {
        XCTAssertEqual(ZenClockTypography.weightLabel(for: 0.49), "Regular")
        XCTAssertEqual(ZenClockTypography.weightLabel(for: 0.5), "Medium")
        XCTAssertEqual(ZenClockTypography.weightLabel(for: 0.77), "Semi Bold")
        XCTAssertEqual(ZenClockTypography.weightLabel(for: 0.78), "Bold")
    }

    func testApplyLookRestoresEngineFields() {
        let s = makeSettings()
        let savedDensity = s.density
        let savedGeometry = s.geometryPreset
        let savedDraw = s.drawSpeed
        let savedLine = s.lineWidth
        let savedGlow = s.glow
        let savedGlowStrength = s.glowStrength
        defer {
            s.density = savedDensity
            s.geometryPreset = savedGeometry
            s.drawSpeed = savedDraw
            s.lineWidth = savedLine
            s.glow = savedGlow
            s.glowStrength = savedGlowStrength
        }
        var cfg = EngineConfig()
        cfg.randomPattern = false
        cfg.geometry = 1
        cfg.cellSize = 0.3
        cfg.drawSpeed = 0.5
        cfg.lineWidth = 2.0
        cfg.glow = false
        cfg.glowStrength = 0.4
        s.applyLook(from: cfg)
        XCTAssertEqual(s.geometryPreset, "medium")
        XCTAssertEqual(s.density, 0.7, accuracy: 0.0001)
        XCTAssertEqual(s.drawSpeed, 0.5, accuracy: 0.0001)
        XCTAssertEqual(s.lineWidth, 2.0, accuracy: 0.0001)
        XCTAssertFalse(s.glow)
        XCTAssertEqual(s.glowStrength, 0.4, accuracy: 0.0001)
    }
}
