// File Purpose: Verifies that widget links survive legacy palette ids.
// Primary Components: DeepLinkPaletteAliasTests.
// I/O: Builds snapshots with legacy and unknown palette ids; asserts the
// encoded mandaza:// link and its decoded snapshot.

import XCTest
#if SWIFT_PACKAGE
@testable import MandazaKit
#endif

final class DeepLinkPaletteAliasTests: XCTestCase {

    func testCanonicalIdResolvesLegacyAliases() {
        XCTAssertEqual(Palette.canonicalId("arctic"), "canopy")
        XCTAssertEqual(Palette.canonicalId("riso"), "risograph")
        XCTAssertEqual(Palette.canonicalId("aurora"), "aurora")
        XCTAssertNil(Palette.canonicalId("not-a-palette"))
    }

    func testWidgetLinkWithLegacyCanopyIdOpensThePattern() throws {
        // The widget's Canopy option still stores the raw value "arctic".
        let widget = MandazaSnapshot(seed: "widget-481234-60-arctic",
                                     paletteId: "arctic",
                                     config: EngineConfig())
        let url = try XCTUnwrap(MandazaDeepLink.url(for: widget))
        let opened = try XCTUnwrap(MandazaDeepLink.snapshot(from: url))
        XCTAssertEqual(opened.seed, widget.seed)
        XCTAssertEqual(opened.paletteId, "canopy")
        XCTAssertEqual(opened.config, widget.config)
    }

    func testUnknownPaletteStillProducesNoLink() {
        let snapshot = MandazaSnapshot(seed: UUID().uuidString,
                                       paletteId: "not-a-palette",
                                       config: EngineConfig())
        XCTAssertNil(MandazaDeepLink.url(for: snapshot))
    }
}
