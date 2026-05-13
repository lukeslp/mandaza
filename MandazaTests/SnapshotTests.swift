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
}
