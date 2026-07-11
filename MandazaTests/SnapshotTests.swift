/*
 File Purpose: Verifies Mandaza snapshot serialization and deep-link safety.
 Primary Components: SnapshotTests.
 Inputs / Outputs: Encodes deterministic snapshots and routes; asserts exact
 round trips, validation boundaries, and legacy widget compatibility.
 */

import XCTest
@testable import Mandaza

final class SnapshotTests: XCTestCase {

    func testSnapshotCodableRoundTrip() throws {
        let original = MandazaSnapshot(
            seed: "fixed-seed-123",
            paletteId: "aurora",
            config: EngineConfig(),
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MandazaSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSnapshotIDEqualsSeed() {
        let snap = MandazaSnapshot(seed: "abc", paletteId: "ember", config: EngineConfig())
        XCTAssertEqual(snap.id, "abc")
    }

    func testEngineConfigCodableRoundTrip() throws {
        var cfg = EngineConfig()
        cfg.drawSpeed = 0.42
        cfg.glow = true
        cfg.glowStrength = 0.44
        cfg.lineWidth = 2.1
        let data = try JSONEncoder().encode(cfg)
        let decoded = try JSONDecoder().decode(EngineConfig.self, from: data)
        XCTAssertEqual(decoded, cfg)
    }

    func testSnapshotDeepLinkRoundTripsCompleteArtwork() throws {
        var config = EngineConfig()
        config.cellSizeRandom = false
        config.cellSize = 0.37
        config.randomPattern = false
        config.geometry = 5
        let original = MandazaSnapshot(
            seed: "widget-12345",
            paletteId: "terrain",
            config: config,
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let url = try XCTUnwrap(MandazaDeepLink.url(for: original))
        XCTAssertEqual(MandazaDeepLink.snapshot(from: url), original)
    }

    func testSnapshotDeepLinkRejectsUnsafeEngineConfiguration() throws {
        var config = EngineConfig()
        config.cellSize = -1
        let snapshot = MandazaSnapshot(seed: "malicious",
                                       paletteId: "aurora",
                                       config: config)
        XCTAssertNil(MandazaDeepLink.url(for: snapshot))

        let raw = try JSONEncoder().encode(snapshot).base64EncodedString()
        var components = URLComponents()
        components.scheme = "mandaza"
        components.host = "snapshot"
        components.queryItems = [URLQueryItem(name: "data", value: raw)]
        XCTAssertNil(MandazaDeepLink.snapshot(from: try XCTUnwrap(components.url)))
    }

    func testSnapshotDeepLinkRejectsUnknownPaletteAndExtraFields() throws {
        let unknown = MandazaSnapshot(seed: "safe",
                                      paletteId: "not-a-palette",
                                      config: EngineConfig())
        XCTAssertNil(MandazaDeepLink.url(for: unknown))
        let extra = try XCTUnwrap(URL(string: "mandaza://snapshot?data=e30=&extra=true"))
        XCTAssertNil(MandazaDeepLink.snapshot(from: extra))
    }

    func testLegacyWidgetSeedLinkRemainsCompatible() throws {
        let url = try XCTUnwrap(URL(string: "mandaza://seed/widget-123-60-aurora"))
        XCTAssertEqual(MandazaDeepLink.seed(from: url), "widget-123-60-aurora")
    }
}
