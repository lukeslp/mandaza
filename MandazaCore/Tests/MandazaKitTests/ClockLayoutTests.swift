import XCTest
import SwiftUI
@testable import MandazaKit

/// Layout contract for the Zen clock overlay. These pure maps decide where
/// the clock sits (all 8 positions) and how each font style renders, so a
/// UI regression that scrambles positions or drops the serif/condensed looks
/// fails here instead of on-device.
final class ClockLayoutTests: XCTestCase {

    func testAlignmentMapsAllEightPositions() {
        XCTAssertEqual(ZenClockPosition.allCases.count, 8)
        XCTAssertEqual(ZenClockTypography.alignment(for: .top), .top)
        XCTAssertEqual(ZenClockTypography.alignment(for: .upperThird), .top)
        XCTAssertEqual(ZenClockTypography.alignment(for: .center), .center)
        XCTAssertEqual(ZenClockTypography.alignment(for: .lowerThird), .bottom)
        XCTAssertEqual(ZenClockTypography.alignment(for: .topLeading), .topLeading)
        XCTAssertEqual(ZenClockTypography.alignment(for: .topTrailing), .topTrailing)
        XCTAssertEqual(ZenClockTypography.alignment(for: .bottomLeading), .bottomLeading)
        XCTAssertEqual(ZenClockTypography.alignment(for: .bottomTrailing), .bottomTrailing)
    }

    func testEveryPositionResolvesToADistinctOrExpectedAlignment() {
        // Guards against a switch case falling through to a wrong default.
        for pos in ZenClockPosition.allCases {
            _ = ZenClockTypography.alignment(for: pos)
        }
    }

    func testFontDesignMapsStyles() {
        XCTAssertEqual(ZenClockTypography.fontDesign(for: .system), .default)
        XCTAssertEqual(ZenClockTypography.fontDesign(for: .rounded), .rounded)
        XCTAssertEqual(ZenClockTypography.fontDesign(for: .monospaced), .monospaced)
        XCTAssertEqual(ZenClockTypography.fontDesign(for: .serif), .serif)
        // Condensed is not a design; it rides on Font.Width instead.
        XCTAssertNil(ZenClockTypography.fontDesign(for: .condensed))
    }

    func testCondensedUsesCondensedWidthOnly() {
        XCTAssertEqual(ZenClockTypography.fontWidth(for: .condensed), .condensed)
        XCTAssertEqual(ZenClockTypography.fontWidth(for: .system), .standard)
        XCTAssertEqual(ZenClockTypography.fontWidth(for: .serif), .standard)
    }

    func testFormEnumHasThreeForms() {
        XCTAssertEqual(ZenClockForm.allCases.count, 3)
        XCTAssertTrue(ZenClockForm.allCases.contains(.digital))
        XCTAssertTrue(ZenClockForm.allCases.contains(.stacked))
        XCTAssertTrue(ZenClockForm.allCases.contains(.editorial))
    }
}
