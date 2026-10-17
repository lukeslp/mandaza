// File Purpose: Verifies that beat onsets, which drive canvas-wide pulses,
// never exceed three per second while ordinary tempos still register.
// Primary Components: OnsetRateTests.
// I/O: Feeds synthetic spectral-flux sequences to SpectrumAnalyzer.isOnset;
// asserts onset counts per one-second span.

import XCTest
#if SWIFT_PACKAGE
@testable import MandazaKit
#endif

final class OnsetRateTests: XCTestCase {

    /// Feeds `windows` flux values, with a spike every `spikeEvery` windows
    /// after a quiet warm-up, and returns the window indices that reported
    /// an onset.
    private func onsetIndices(sampleRate: Double,
                              windows: Int,
                              spikeEvery: Int,
                              warmup: Int = 40) -> [Int] {
        let analyzer = SpectrumAnalyzer(sampleRate: sampleRate)
        for _ in 0..<warmup { _ = analyzer.isOnset(flux: 0.05) }
        var hits: [Int] = []
        for i in 0..<windows {
            let flux: Float = i % spikeEvery == 0 ? 1.0 : 0.05
            if analyzer.isOnset(flux: flux) { hits.append(i) }
        }
        return hits
    }

    private func maxOnsetsPerSecond(_ hits: [Int], windowSeconds: Double) -> Int {
        let span = Int((1.0 / windowSeconds).rounded(.down))
        return hits.map { start in hits.filter { $0 >= start && $0 < start + span }.count }
            .max() ?? 0
    }

    func testDensePercussionIsCappedAtThreePerSecond() {
        for rate in [44_100.0, 48_000.0] {
            let windowSeconds = 1024.0 / rate
            // A spike every 4 windows is ~11 Hz: a fast hi-hat or drum roll.
            let hits = onsetIndices(sampleRate: rate, windows: 600, spikeEvery: 4)
            XCTAssertFalse(hits.isEmpty)
            XCTAssertLessThanOrEqual(maxOnsetsPerSecond(hits, windowSeconds: windowSeconds), 3,
                                     "sample rate \(rate)")
            for (a, b) in zip(hits, hits.dropFirst()) {
                XCTAssertGreaterThanOrEqual(Double(b - a) * windowSeconds,
                                            SpectrumAnalyzer.minimumOnsetInterval)
            }
        }
    }

    func testOrdinaryTempoStillLandsOnEveryBeat() {
        // 120 BPM: one beat every 0.5 s, about 23–24 windows.
        let rate = 48_000.0
        let spikeEvery = Int((0.5 / (1024.0 / rate)).rounded())
        let windows = spikeEvery * 20
        let hits = onsetIndices(sampleRate: rate, windows: windows, spikeEvery: spikeEvery)
        XCTAssertEqual(hits, Array(stride(from: 0, to: windows, by: spikeEvery)))
    }

    func testFirstOnsetIsNotDelayed() {
        let analyzer = SpectrumAnalyzer(sampleRate: 48_000)
        for _ in 0..<10 { _ = analyzer.isOnset(flux: 0.05) }
        XCTAssertTrue(analyzer.isOnset(flux: 1.0))
    }
}
