import XCTest
@testable import Mandaza

final class EngineTests: XCTestCase {

    func testRegenerateProducesLoops() {
        let engine = MandazaEngine()
        XCTAssertTrue(engine.regenerate(width: 414, height: 896, seed: "fixed-seed"))
        XCTAssertFalse(engine.loops.isEmpty)
    }

    func testCompleteAllPathsTerminates() {
        let engine = MandazaEngine()
        XCTAssertTrue(engine.regenerate(width: 414, height: 896, seed: "fixed-seed"))
        engine.completeAllPaths()
        XCTAssertTrue(engine.allDrawn)
    }

    func testDeterministicWithSameSeed() {
        let a = MandazaEngine(); _ = a.regenerate(width: 800, height: 600, seed: "abc")
        let b = MandazaEngine(); _ = b.regenerate(width: 800, height: 600, seed: "abc")
        XCTAssertEqual(a.loops.count, b.loops.count)
    }

    func testTinyCanvasFails() {
        let engine = MandazaEngine()
        XCTAssertFalse(engine.regenerate(width: 1, height: 1, seed: "tiny"))
    }

    func testPaletteInterpolationStaysClamped() {
        let p = Palette.by(id: "aurora")
        _ = p.interpolated(at: -2.0)
        _ = p.interpolated(at: 5.0)
        _ = p.interpolatedCGColor(at: -2.0)
        _ = p.interpolatedCGColor(at: 5.0)
    }

    func testRenamedRisoPaletteResolves() {
        // Legacy @AppStorage values may still hold "riso"; ensure they don't crash.
        XCTAssertEqual(Palette.by(id: "riso").id, "risograph")
        XCTAssertEqual(Palette.by(id: "risograph").id, "risograph")
    }

    func testRenderImageProducesNonEmptyOutput() {
        let image = MandazaEngine.renderImage(
            seed: "fixed-seed",
            paletteId: "aurora",
            config: EngineConfig(),
            size: CGSize(width: 600, height: 600)
        )
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size.width, 600)
        XCTAssertEqual(image?.size.height, 600)
    }

    func testRenderImageRejectsDegenerateSizes() {
        let none = MandazaEngine.renderImage(
            seed: "fixed-seed",
            paletteId: "aurora",
            config: EngineConfig(),
            size: CGSize(width: 0, height: 0)
        )
        XCTAssertNil(none)
    }

    func testStructuralConfigurationChangesRequireRebuild() {
        let original = EngineConfig()
        var density = original
        density.cellSizeRandom = false
        density.cellSize = 0.4
        XCTAssertTrue(density.requiresRebuild(comparedTo: original))

        var geometry = original
        geometry.randomPattern = false
        geometry.geometry = 2
        XCTAssertTrue(geometry.requiresRebuild(comparedTo: original))
    }

    func testPresentationConfigurationChangesDoNotRequireRebuild() {
        let original = EngineConfig()
        var changed = original
        changed.drawSpeed = 0.2
        changed.glow = true
        changed.glowStrength = 0.4
        changed.idlePulse = false
        changed.lineWidth = 2.5
        XCTAssertFalse(changed.requiresRebuild(comparedTo: original))
    }
}
