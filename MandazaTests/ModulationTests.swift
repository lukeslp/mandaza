import XCTest
@testable import Mandaza

/// The drawScene modulation mapping lives in a private method of
/// `MandazaCanvas`, so these tests replicate the mapping formulas as pure
/// expressions and pin the spec constants: strokeWidth multiplier clamped
/// to 1.0...1.55, glowScale clamped 0.18...1.0 with a +0.40 * bass boost,
/// and shadow opacity capped at 0.95.
final class ModulationTests: XCTestCase {

    private func widthMultiplier(level: Double, beatPulse: Double) -> Double {
        min(max(1 + 0.30 * level + 0.20 * beatPulse, 1.0), 1.55)
    }

    private func glowScale(base: Double, bass: Double) -> Double {
        let clampedBase = min(max(base, 0.18), 1.0)
        return min(max(clampedBase + 0.40 * bass, 0.18), 1.0)
    }

    private func shadowOpacity(glowScale: Double, beatPulse: Double) -> Double {
        min(0.95, 0.55 + 0.30 * glowScale + 0.12 * beatPulse)
    }

    func testStrokeWidthMultiplierClampsAtExtremes() {
        XCTAssertEqual(widthMultiplier(level: 0, beatPulse: 0), 1.0, accuracy: 1e-12)
        XCTAssertEqual(widthMultiplier(level: 1, beatPulse: 1), 1.5, accuracy: 1e-12)
        XCTAssertLessThanOrEqual(widthMultiplier(level: 2, beatPulse: 2), 1.55)
        XCTAssertGreaterThanOrEqual(widthMultiplier(level: -1, beatPulse: -1), 1.0)
    }

    func testGlowScaleClampWithBassBoost() {
        XCTAssertEqual(glowScale(base: 0.0, bass: 0.0), 0.18, accuracy: 1e-12)
        XCTAssertEqual(glowScale(base: 1.0, bass: 0.0), 1.0, accuracy: 1e-12)
        XCTAssertEqual(glowScale(base: 0.5, bass: 0.5), 0.70, accuracy: 1e-12)
        XCTAssertEqual(glowScale(base: 0.9, bass: 1.0), 1.0, accuracy: 1e-12)
    }

    func testShadowOpacityCap() {
        XCTAssertEqual(shadowOpacity(glowScale: 0.18, beatPulse: 0),
                       0.55 + 0.30 * 0.18, accuracy: 1e-12)
        XCTAssertEqual(shadowOpacity(glowScale: 1.0, beatPulse: 1.0), 0.95, accuracy: 1e-12)
        XCTAssertLessThanOrEqual(shadowOpacity(glowScale: 1.0, beatPulse: 2.0), 0.95)
    }

    func testZeroModulationIsIdentity() {
        let zero = MandazaModulation.zero
        XCTAssertEqual(zero.level, 0)
        XCTAssertEqual(zero.bass, 0)
        XCTAssertEqual(zero.mid, 0)
        XCTAssertEqual(zero.treble, 0)
        XCTAssertEqual(zero.beatPulse, 0)
        XCTAssertEqual(zero.colorPhaseMs, 0)

        XCTAssertEqual(widthMultiplier(level: zero.level, beatPulse: zero.beatPulse),
                       1.0, accuracy: 1e-12)
        XCTAssertEqual(0.40 * zero.bass, 0.0, accuracy: 1e-12)
        XCTAssertEqual(shadowOpacity(glowScale: 1.0, beatPulse: zero.beatPulse),
                       0.55 + 0.30 * 1.0, accuracy: 1e-12)
    }

    func testValueSemanticsAndEquatable() {
        var a = MandazaModulation.zero
        let b = a
        a.bass = 0.7
        XCTAssertEqual(b, MandazaModulation.zero)
        XCTAssertNotEqual(a, b)
    }

    @MainActor
    func testModulationSourceDefaults() {
        let source = MandazaModulationSource()
        XCTAssertEqual(source.modulation, .zero)
        XCTAssertFalse(source.isActive)
    }
}
