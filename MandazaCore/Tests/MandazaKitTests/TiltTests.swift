import XCTest
import CoreGraphics
@testable import MandazaKit

/// Contract for the tilt-parallax mapping. `tiltOffset` is the pure geometry
/// under the CoreMotion-backed `TiltProvider`: off ⇒ no motion, a clamp that
/// never exceeds a small fraction of the view, and an offset that opposes the
/// tilt so the layer reads as depth.
final class TiltTests: XCTestCase {

    private let size = CGSize(width: 400, height: 800)

    func testOffIsAlwaysZero() {
        XCTAssertEqual(tiltOffset(pitch: 0.5, roll: 0.5, intensity: .off, viewSize: size), .zero)
        XCTAssertEqual(tiltOffset(pitch: 10, roll: -10, intensity: .off, viewSize: size), .zero)
    }

    func testPronouncedClampsToMaxFraction() {
        let maxFrac = 0.05 * Double(min(size.width, size.height)) // 20
        // An extreme tilt saturates exactly at the clamp on both axes.
        let o = tiltOffset(pitch: 10, roll: 10, intensity: .pronounced, viewSize: size)
        XCTAssertEqual(abs(o.width), maxFrac, accuracy: 1e-9)
        XCTAssertEqual(abs(o.height), maxFrac, accuracy: 1e-9)
        // And never exceeds it for any input.
        let o2 = tiltOffset(pitch: 3, roll: -3, intensity: .pronounced, viewSize: size)
        XCTAssertLessThanOrEqual(abs(o2.width), maxFrac + 1e-9)
        XCTAssertLessThanOrEqual(abs(o2.height), maxFrac + 1e-9)
    }

    func testSubtleIsSmallerThanPronounced() {
        let s = tiltOffset(pitch: 10, roll: 10, intensity: .subtle, viewSize: size)
        let p = tiltOffset(pitch: 10, roll: 10, intensity: .pronounced, viewSize: size)
        XCTAssertLessThan(abs(s.width), abs(p.width))
        XCTAssertLessThan(abs(s.height), abs(p.height))
        XCTAssertEqual(abs(s.width), 0.02 * Double(min(size.width, size.height)), accuracy: 1e-9)
    }

    func testOffsetIsOppositeToRoll() {
        // Positive roll → negative x offset (mandala shifts against the tilt).
        let pos = tiltOffset(pitch: 0, roll: 0.3, intensity: .pronounced, viewSize: size)
        XCTAssertLessThan(pos.width, 0)
        let neg = tiltOffset(pitch: 0, roll: -0.3, intensity: .pronounced, viewSize: size)
        XCTAssertGreaterThan(neg.width, 0)
    }

    func testOffsetIsOppositeToPitch() {
        let up = tiltOffset(pitch: 0.3, roll: 0, intensity: .pronounced, viewSize: size)
        XCTAssertLessThan(up.height, 0)
        let down = tiltOffset(pitch: -0.3, roll: 0, intensity: .pronounced, viewSize: size)
        XCTAssertGreaterThan(down.height, 0)
    }

    func testClampScalesWithShorterEdge() {
        // Uses min(w,h): a wide, short view clamps off the height.
        let wide = CGSize(width: 1000, height: 200)
        let maxFrac = 0.05 * 200.0
        let o = tiltOffset(pitch: 10, roll: 10, intensity: .pronounced, viewSize: wide)
        XCTAssertEqual(abs(o.width), maxFrac, accuracy: 1e-9)
    }

    @MainActor
    func testProviderStartsAtZeroAndStopsClean() {
        let provider = TiltProvider()
        XCTAssertEqual(provider.offset, .zero)
        provider.viewSize = size
        provider.start(intensity: .off) // off is inert on every platform
        XCTAssertEqual(provider.offset, .zero)
        provider.stop()
        XCTAssertEqual(provider.offset, .zero)
    }
}
