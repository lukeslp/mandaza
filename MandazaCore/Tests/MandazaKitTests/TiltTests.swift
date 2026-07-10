import XCTest
import CoreGraphics
@testable import MandazaKit

/// Contract for the gravity-based tilt-parallax mapping. `tiltOffset` is the
/// pure geometry under the CoreMotion-backed `TiltProvider`: off ⇒ no motion,
/// flat ⇒ faded out, a clamp that never exceeds a small fraction of the view,
/// and an offset that shifts *with* the tilt.
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
                       intensity: .off, viewSize: size),
            .zero)
    }

    func testFlatFadesToZero() {
        // Face-up on a table: gravity ≈ (0, 0, −1). No stable parallax.
        let flat = tiltOffset(gravityX: 0.2, gravityY: 0.0, gravityZ: -1.0,
                              intensity: .pronounced, viewSize: size)
        XCTAssertEqual(flat, .zero)

        // Nearly flat still fades out.
        let nearFlat = tiltOffset(gravityX: 0.3, gravityY: -0.2, gravityZ: -0.9,
                                  intensity: .pronounced, viewSize: size)
        XCTAssertEqual(nearFlat, .zero)
    }

    func testPronouncedClampsToMaxFractionWhenUpright() {
        let maxFrac = 0.05 * Double(min(size.width, size.height)) // 20
        let o = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           intensity: .pronounced, viewSize: size)
        XCTAssertEqual(abs(o.width), maxFrac, accuracy: 1e-9)
        XCTAssertEqual(abs(o.height), maxFrac, accuracy: 1e-9)

        let o2 = tiltOffset(gravityX: 0.9, gravityY: uprightY, gravityZ: -0.9,
                            intensity: .pronounced, viewSize: size)
        XCTAssertLessThanOrEqual(abs(o2.width), maxFrac + 1e-9)
        XCTAssertLessThanOrEqual(abs(o2.height), maxFrac + 1e-9)
    }

    func testSubtleIsSmallerThanPronounced() {
        let s = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           intensity: .subtle, viewSize: size)
        let p = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           intensity: .pronounced, viewSize: size)
        XCTAssertLessThan(abs(s.width), abs(p.width))
        XCTAssertLessThan(abs(s.height), abs(p.height))
        XCTAssertEqual(abs(s.width), 0.02 * Double(min(size.width, size.height)), accuracy: 1e-9)
    }

    func testOffsetFollowsLateralTilt() {
        // Right edge down (positive gravityX) → artwork moves right.
        let right = tiltOffset(gravityX: 0.3, gravityY: uprightY, gravityZ: 0,
                               intensity: .pronounced, viewSize: size)
        XCTAssertGreaterThan(right.width, 0)
        let left = tiltOffset(gravityX: -0.3, gravityY: uprightY, gravityZ: 0,
                              intensity: .pronounced, viewSize: size)
        XCTAssertLessThan(left.width, 0)
    }

    func testOffsetFollowsLongitudinalTilt() {
        // Lean toward face-up (negative gravityZ from upright) → negative Y offset.
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
        let maxFrac = 0.05 * 200.0
        let o = tiltOffset(gravityX: 1, gravityY: uprightY, gravityZ: 1,
                           intensity: .pronounced, viewSize: wide)
        XCTAssertEqual(abs(o.width), maxFrac, accuracy: 1e-9)
    }

    @MainActor
    func testProviderStartsAtZeroAndStopsClean() {
        let provider = TiltProvider()
        XCTAssertEqual(provider.offset, .zero)
        provider.viewSize = size
        provider.start(intensity: .off)
        XCTAssertEqual(provider.offset, .zero)
        provider.stop()
        XCTAssertEqual(provider.offset, .zero)
    }
}
