/*
 File Purpose: Verifies snapshot serialization, engine configuration, and
 externally supplied Mandaza seed routes.
 Primary Components: SnapshotTests.
 Inputs / Outputs: Creates deterministic value fixtures and URLs; asserts
 round trips, stable identifiers, and strict deep-link validation.
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

    func testSeedDeepLinkAcceptsOneUUIDPathComponent() throws {
        let uuid = try XCTUnwrap(UUID(uuidString: "4B8B7437-6D75-49AC-A813-F2CA68D1AF40"))
        let url = try XCTUnwrap(URL(string: "mandaza://seed/\(uuid.uuidString.lowercased())"))
        XCTAssertEqual(MandazaDeepLink.seed(from: url), uuid.uuidString)
    }

    func testSeedDeepLinkRejectsMalformedOrUnexpectedRoutes() throws {
        let malformed = try XCTUnwrap(URL(string: "mandaza://seed/not-a-uuid"))
        let extraPath = try XCTUnwrap(URL(string: "mandaza://seed/4B8B7437-6D75-49AC-A813-F2CA68D1AF40/extra"))
        let wrongHost = try XCTUnwrap(URL(string: "mandaza://palette/4B8B7437-6D75-49AC-A813-F2CA68D1AF40"))
        let doubledSlash = try XCTUnwrap(URL(string: "mandaza://seed//4B8B7437-6D75-49AC-A813-F2CA68D1AF40"))
        let trailingSlash = try XCTUnwrap(URL(string: "mandaza://seed/4B8B7437-6D75-49AC-A813-F2CA68D1AF40/"))
        let query = try XCTUnwrap(URL(string: "mandaza://seed/4B8B7437-6D75-49AC-A813-F2CA68D1AF40?source=external"))
        let userInfo = try XCTUnwrap(URL(string: "mandaza://user@seed/4B8B7437-6D75-49AC-A813-F2CA68D1AF40"))

        XCTAssertNil(MandazaDeepLink.seed(from: malformed))
        XCTAssertNil(MandazaDeepLink.seed(from: extraPath))
        XCTAssertNil(MandazaDeepLink.seed(from: wrongHost))
        XCTAssertNil(MandazaDeepLink.seed(from: doubledSlash))
        XCTAssertNil(MandazaDeepLink.seed(from: trailingSlash))
        XCTAssertNil(MandazaDeepLink.seed(from: query))
        XCTAssertNil(MandazaDeepLink.seed(from: userInfo))
    }

    func testSnapshotDeepLinkRoundTripsCompleteArtwork() throws {
        var config = EngineConfig()
        config.cellSizeRandom = false
        config.cellSize = 0.37
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

    func testSnapshotDeepLinkRejectsExtraFields() throws {
        let url = try XCTUnwrap(URL(string: "mandaza://snapshot?data=e30=&extra=true"))
        XCTAssertNil(MandazaDeepLink.snapshot(from: url))
    }

    func testSnapshotDeepLinkRejectsUnsafeEngineConfiguration() throws {
        var config = EngineConfig()
        config.cellSizeRandom = false
        config.cellSize = -1
        let snapshot = MandazaSnapshot(
            seed: "malicious",
            paletteId: "aurora",
            config: config
        )
        let url = try XCTUnwrap(MandazaDeepLink.url(for: snapshot))
        XCTAssertNil(MandazaDeepLink.snapshot(from: url))
    }
}
