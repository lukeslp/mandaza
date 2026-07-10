import XCTest
@testable import MandazaKit

@MainActor
final class SettingsNewFieldsTests: XCTestCase {
    func testDefaults() {
        let s = MandazaSettings.shared
        XCTAssertEqual(s.reactivity, 0.35, accuracy: 0.001)
        XCTAssertTrue(s.musicResponsivity)          // on by default (iOS/watchOS)
        XCTAssertEqual(s.zenTiltIntensity, .subtle)
        XCTAssertEqual(s.zenClockForm, .digital)
    }
    func testClockPositionCasesExpanded() {
        XCTAssertEqual(ZenClockPosition.allCases.count, 8)
        XCTAssertEqual(ZenClockFontStyle.allCases.count, 5)
    }
}
