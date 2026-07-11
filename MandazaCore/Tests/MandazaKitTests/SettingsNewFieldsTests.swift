// File Purpose: Verifies defaults and typed accessors for recently added
// clock, music, parallax, and canvas settings.
// Primary Components: SettingsNewFieldsTests.
// I/O: Uses an isolated UserDefaults suite; asserts deterministic settings
// hydration without touching the developer's persisted app preferences.

import XCTest
#if SWIFT_PACKAGE
@testable import MandazaKit
#endif

@MainActor
final class SettingsNewFieldsTests: XCTestCase {
    func testDefaults() {
        let suiteName = "MandazaKitTests.SettingsNewFields.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let s = MandazaSettings(defaults: defaults, migrate: false)
        XCTAssertEqual(s.reactivity, 0.35, accuracy: 0.001)
        XCTAssertFalse(s.musicResponsivity)
        XCTAssertFalse(s.zenTiltEnabled)
        XCTAssertEqual(s.zenTiltIntensity, .off)
        XCTAssertEqual(s.zenTiltDepth, 0.85, accuracy: 0.001)
        XCTAssertFalse(s.zenTiltInvertDepth)
        XCTAssertEqual(s.zenTiltAxes, .both)
        XCTAssertEqual(s.canvasTheme, .void)
        XCTAssertEqual(s.zenClockForm, .digital)
    }
    func testClockPositionCasesExpanded() {
        XCTAssertEqual(ZenClockPosition.allCases.count, 8)
        XCTAssertEqual(ZenClockFontStyle.allCases.count, 5)
    }
}
