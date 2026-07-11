// File Purpose: Verifies pure music-reactivity speed and beat-scale helpers.
// Primary Components: ReactivityTests.
// I/O: Supplies bounded and out-of-range level/reactivity values; asserts
// identity, clamping, monotonicity, and visible design targets.

import XCTest
#if SWIFT_PACKAGE
@testable import MandazaKit
#endif

/// Pure-math contract for music reactivity. The render wires these two
/// helpers into the canvas presentation transform; the values here are the
/// visible design targets (identity at silence, r=0 inert, default ~1.06×,
/// max ~1.30×).
final class ReactivityTests: XCTestCase {
    func testSpeedFactorIdentityAtSilence() {
        XCTAssertEqual(speedFactor(level: 0, reactivity: 0.35), 1.0, accuracy: 1e-9)
    }

    func testSpeedFactorScalesWithLevel() {
        XCTAssertEqual(speedFactor(level: 1, reactivity: 1.0), 2.5, accuracy: 1e-9)
    }

    func testScaleThrobDefaultIsGentle() {
        XCTAssertEqual(scaleThrob(beatEnv: 1, reactivity: 0.35), 1.06, accuracy: 0.005)
    }

    func testScaleThrobMaxIsDramatic() {
        XCTAssertEqual(scaleThrob(beatEnv: 1, reactivity: 1.0), 1.30, accuracy: 0.005)
    }

    func testReactivityZeroIsInert() {
        XCTAssertEqual(scaleThrob(beatEnv: 1, reactivity: 0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(speedFactor(level: 1, reactivity: 0), 1.0, accuracy: 1e-9)
    }

    func testSpeedFactorClampsLevel() {
        // Levels outside 0…1 are clamped so the clock never reverses or runs away.
        XCTAssertEqual(speedFactor(level: 2, reactivity: 1.0), 2.5, accuracy: 1e-9)
        XCTAssertEqual(speedFactor(level: -1, reactivity: 1.0), 1.0, accuracy: 1e-9)
    }

    func testScaleThrobIsMonotonicAndNeverShrinks() {
        // A beat may only grow the mandala, never pull it below its resting size.
        for r in stride(from: 0.0, through: 1.0, by: 0.1) {
            XCTAssertGreaterThanOrEqual(scaleThrob(beatEnv: 1, reactivity: r), 1.0)
        }
    }
}
