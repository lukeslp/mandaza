import XCTest
@testable import Mandaza

@MainActor
final class SettingsTests: XCTestCase {

    func testEngineConfigReflectsLookValues() {
        let s = MandazaSettings.shared
        s.drawSpeed = 0.8
        s.lineWidth = 2.5
        s.glow = false
        let cfg = s.engineConfig()
        XCTAssertEqual(cfg.drawSpeed, 0.8, accuracy: 0.0001)
        XCTAssertEqual(cfg.lineWidth, 2.5, accuracy: 0.0001)
        XCTAssertFalse(cfg.glow)
    }

    func testEngineConfigMapsDensityToCellSize() {
        let s = MandazaSettings.shared
        s.density = 0.0
        XCTAssertEqual(s.engineConfig().cellSize, 1.0, accuracy: 0.0001)
        s.density = 1.0
        XCTAssertEqual(s.engineConfig().cellSize, 0.05, accuracy: 0.0001)
        s.density = 0.5
        XCTAssertEqual(s.engineConfig().cellSize, 0.5, accuracy: 0.0001)
    }

    func testEngineConfigGeometryPresets() {
        let s = MandazaSettings.shared
        s.geometryPreset = "auto"
        XCTAssertTrue(s.engineConfig().randomPattern)
        s.geometryPreset = "sparse"
        XCTAssertFalse(s.engineConfig().randomPattern)
        XCTAssertEqual(s.engineConfig().geometry, 0)
        s.geometryPreset = "busy"
        XCTAssertEqual(s.engineConfig().geometry, 6)
    }

    func testFavoritesToggleAddsAndRemoves() {
        let s = MandazaSettings.shared
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
        let s = MandazaSettings.shared
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
}
