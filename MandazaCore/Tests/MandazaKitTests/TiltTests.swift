import XCTest
import CoreGraphics
#if SWIFT_PACKAGE
@testable import MandazaKit
#endif

/// Contract for the gravity-based tilt-parallax mapping. `tiltOffset` is the
/// pure geometry under the CoreMotion-backed `TiltProvider`: off ⇒ no motion,
/// a clamp that never exceeds a small fraction of the view, and an offset that
/// shifts *with* the tilt. `ambientParallaxOffset` adds faint Zen-mode drift.
final class TiltTests: XCTestCase {

    private let size = CGSize(width: 400, height: 800)

    /// Upright portrait resting pose: gravity ≈ (0, −1, 0).
    private let uprightY = -1.0

    func testOffIsAlwaysZero() {
        XCTAssertEqual(
            tiltOffset(gravityX: 0.5, gravityY: uprightY, gravityZ: 0.5,
                       intensity: .off, viewSize: size),
            .zero)
        XCTAssertEqual(
            tiltOffset(gravityX: 10, gravityY: uprightY, gravityZ: -10,
                       amount: 0, axes: .both, viewSize: size),
            .zero)
    }

    func testFlatFaceUpClampsStably() {
        // Face-up on a table: gravity ≈ (0, 0, −1). Offset parks at the Y clamp
        // (no thrash — gravity is steady when flat).
        let maxFrac = tiltMaxTravelFraction * Double(min(size.width, size.height))
        let flat = tiltOffset(gravityX: 0, gravityY: 0, gravityZ: -1,
                              intensity: .pronounced, viewSize: size)
        XCTAssertEqual(flat.width, 0, accuracy: 1e-9)
        XCTAssertEqual(flat.height, -maxFrac, accuracy: 1e-9)
    }

    func testReclinedReadingAngleStillResponds() {
        // ~60° from vertical toward face-up — a normal reading pose. Must not
        // zero out (the old upright-fade froze parallax here).
        let gY = -0.5
        let gZ = -0.85
        let o = tiltOffset(gravityX: 0.25, gravityY: gY, gravityZ: gZ,
                           intensity: .pronounced, viewSize: size)
        XCTAssertNotEqual(o, .zero)
        XCTAssertGreaterThan(o.width, 0)
        XCTAssertLessThan(o.height, 0)
    }

    func testPronouncedClampsToMaxFractionWhenUpright() {
        let maxFrac = tiltMaxTravelFraction * Double(min(size.width, size.height))
        let o = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           intensity: .pronounced, viewSize: size)
        XCTAssertEqual(abs(o.width), maxFrac, accuracy: 1e-9)
        XCTAssertEqual(abs(o.height), maxFrac, accuracy: 1e-9)
    }

    func testSubtleIsSmallerThanPronounced() {
        let s = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           intensity: .subtle, viewSize: size)
        let p = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           intensity: .pronounced, viewSize: size)
        XCTAssertLessThan(abs(s.width), abs(p.width))
        XCTAssertEqual(abs(s.width),
                       0.5 * tiltMaxTravelFraction * Double(min(size.width, size.height)),
                       accuracy: 1e-9)
    }

    func testAmountOneUsesMaxTravelFraction() {
        let maxFrac = tiltMaxTravelFraction * Double(min(size.width, size.height))
        let o = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           amount: 1, axes: .both, viewSize: size)
        XCTAssertEqual(abs(o.width), maxFrac, accuracy: 1e-9)
    }

    func testHorizontalAxesZeroesVertical() {
        let o = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           amount: 1, axes: .horizontal, viewSize: size)
        XCTAssertGreaterThan(abs(o.width), 0)
        XCTAssertEqual(o.height, 0, accuracy: 1e-9)
    }

    func testVerticalAxesZeroesHorizontal() {
        let o = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           amount: 1, axes: .vertical, viewSize: size)
        XCTAssertEqual(o.width, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(abs(o.height), 0)
    }

    func testHorizontalIsCalmerThanVerticalAtEqualTilt() {
        // Same gravity magnitude on each axis should travel less horizontally
        // (roll swings gravityX far for a small twist, so it's damped).
        let o = tiltOffset(gravityX: 0.2, gravityY: uprightY, gravityZ: 0.2,
                           amount: 1, axes: .both, viewSize: size)
        XCTAssertGreaterThan(abs(o.width), 0)
        XCTAssertLessThan(abs(o.width), abs(o.height))
    }

    func testOffsetFollowsLateralTilt() {
        let right = tiltOffset(gravityX: 0.3, gravityY: uprightY, gravityZ: 0,
                               intensity: .pronounced, viewSize: size)
        XCTAssertGreaterThan(right.width, 0)
        let left = tiltOffset(gravityX: -0.3, gravityY: uprightY, gravityZ: 0,
                              intensity: .pronounced, viewSize: size)
        XCTAssertLessThan(left.width, 0)
    }

    func testOffsetFollowsLongitudinalTilt() {
        let back = tiltOffset(gravityX: 0, gravityY: uprightY, gravityZ: -0.3,
                              intensity: .pronounced, viewSize: size)
        XCTAssertLessThan(back.height, 0)
        let forward = tiltOffset(gravityX: 0, gravityY: uprightY, gravityZ: 0.3,
                                 intensity: .pronounced, viewSize: size)
        XCTAssertGreaterThan(forward.height, 0)
    }

    func testUprightRestIsNearZero() {
        let rest = tiltOffset(gravityX: 0, gravityY: uprightY, gravityZ: 0,
                              intensity: .pronounced, viewSize: size)
        XCTAssertEqual(rest, .zero)
    }

    func testClampScalesWithShorterEdge() {
        let wide = CGSize(width: 1000, height: 200)
        let maxFrac = tiltMaxTravelFraction * 200.0
        let o = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           intensity: .pronounced, viewSize: wide)
        XCTAssertEqual(abs(o.width), maxFrac, accuracy: 1e-9)
    }

    func testAmbientSwayIsZeroWhenAmountOff() {
        XCTAssertEqual(
            ambientParallaxOffset(time: 4, amount: 0, viewSize: size),
            .zero)
    }

    func testAmbientSwayDriftsOverTime() {
        let a = ambientParallaxOffset(time: 0, amount: 1, viewSize: size)
        let b = ambientParallaxOffset(time: 3.5, amount: 1, viewSize: size)
        XCTAssertNotEqual(a, b)
        let maxTravel = tiltMaxTravelFraction * 0.30 * Double(min(size.width, size.height))
        XCTAssertLessThanOrEqual(abs(a.width), maxTravel + 1e-9)
        XCTAssertLessThanOrEqual(abs(a.height), maxTravel + 1e-9)
    }

    func testAmbientSwayRespectsAxes() {
        let h = ambientParallaxOffset(time: 5, amount: 1, axes: .horizontal, viewSize: size)
        XCTAssertEqual(h.height, 0, accuracy: 1e-9)
        let v = ambientParallaxOffset(time: 5, amount: 1, axes: .vertical, viewSize: size)
        XCTAssertEqual(v.width, 0, accuracy: 1e-9)
    }

    func testCombinedTiltAndAmbientStayWithinTravelCap() {
        let limit = tiltMaxTravelFraction * Double(min(size.width, size.height))
        let combined = clampedParallaxOffset(
            CGSize(width: limit * 1.3, height: -limit * 1.3),
            amount: 1,
            viewSize: size)
        XCTAssertEqual(combined.width, limit, accuracy: 1e-9)
        XCTAssertEqual(combined.height, -limit, accuracy: 1e-9)
    }

    func testParallaxDepthScalesWithLuminance() {
        XCTAssertLessThan(parallaxDepth(luminance: 0.1), parallaxDepth(luminance: 0.9))
        XCTAssertEqual(parallaxDepth(luminance: 0), 0.22, accuracy: 1e-9)
        XCTAssertEqual(parallaxDepth(luminance: 1), 1.0, accuracy: 1e-9)
    }

    func testParallaxDepthContrastFlattens() {
        let a = parallaxDepth(luminance: 0.1, contrast: 0)
        let b = parallaxDepth(luminance: 0.9, contrast: 0)
        XCTAssertEqual(a, b, accuracy: 1e-9)
        XCTAssertEqual(a, 0.22 + 0.78 * 0.5, accuracy: 1e-9)
    }

    func testParallaxDepthInvertSwapsNearFar() {
        let bright = parallaxDepth(luminance: 0.9, invert: false)
        let darkNear = parallaxDepth(luminance: 0.1, invert: true)
        XCTAssertEqual(bright, darkNear, accuracy: 1e-9)
        XCTAssertGreaterThan(parallaxDepth(luminance: 0.1, invert: true),
                             parallaxDepth(luminance: 0.9, invert: true))
    }

    @MainActor
    func testProviderStartsAtZeroAndStopsClean() {
        let provider = TiltProvider()
        XCTAssertEqual(provider.offset, .zero)
        provider.viewSize = size
        provider.start(amount: 0)
        XCTAssertEqual(provider.offset, .zero)
        provider.stop()
        XCTAssertEqual(provider.offset, .zero)
    }

    @MainActor
    func testListenerReceivesCurrentAndUpdates() {
        let provider = TiltProvider()
        var seen: [CGSize] = []
        let id = provider.addListener { seen.append($0) }
        XCTAssertEqual(seen.count, 1)
        XCTAssertEqual(seen[0], .zero)
        provider.removeListener(id)
    }
}
