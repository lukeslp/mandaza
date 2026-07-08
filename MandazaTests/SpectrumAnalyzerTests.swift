import XCTest
@testable import Mandaza

final class SpectrumAnalyzerTests: XCTestCase {

    private let sampleRate = 48_000.0

    private func sineBuffer(frequency: Double, count: Int, amplitude: Float = 0.8) -> [Float] {
        (0..<count).map { i in
            amplitude * Float(sin(2.0 * .pi * frequency * Double(i) / sampleRate))
        }
    }

    func testBassToneDominatesBassBand() {
        let analyzer = SpectrumAnalyzer(sampleRate: sampleRate)
        let bands = analyzer.analyze(sineBuffer(frequency: 100, count: analyzer.fftSize))
        XCTAssertGreaterThan(bands.bass, bands.mid)
        XCTAssertGreaterThan(bands.bass, bands.treble)
    }

    func testMidToneDominatesMidBand() {
        let analyzer = SpectrumAnalyzer(sampleRate: sampleRate)
        let bands = analyzer.analyze(sineBuffer(frequency: 1_000, count: analyzer.fftSize))
        XCTAssertGreaterThan(bands.mid, bands.bass)
        XCTAssertGreaterThan(bands.mid, bands.treble)
    }

    func testTrebleToneDominatesTrebleBand() {
        let analyzer = SpectrumAnalyzer(sampleRate: sampleRate)
        let bands = analyzer.analyze(sineBuffer(frequency: 4_000, count: analyzer.fftSize))
        XCTAssertGreaterThan(bands.treble, bands.bass)
        XCTAssertGreaterThan(bands.treble, bands.mid)
    }

    func testSteadyToneKeepsFluxLowWithNoOnset() {
        let analyzer = SpectrumAnalyzer(sampleRate: sampleRate)
        let buffer = sineBuffer(frequency: 440, count: analyzer.fftSize)
        // Warm-up: the first frame reports inflated flux by design
        // (previous frame is silence); feed it into the onset history too.
        for _ in 0..<8 {
            let bands = analyzer.analyze(buffer)
            _ = analyzer.isOnset(flux: bands.flux)
        }
        for _ in 0..<10 {
            let bands = analyzer.analyze(buffer)
            XCTAssertLessThan(bands.flux, 0.01)
            XCTAssertFalse(analyzer.isOnset(flux: bands.flux))
        }
    }

    func testAmplitudeStepSpikesFluxAndTriggersOnset() {
        let analyzer = SpectrumAnalyzer(sampleRate: sampleRate)
        let quiet = sineBuffer(frequency: 440, count: analyzer.fftSize, amplitude: 0.25)
        let loud = sineBuffer(frequency: 440, count: analyzer.fftSize, amplitude: 0.9)
        var baseline = SpectrumBands()
        for _ in 0..<4 {
            baseline = analyzer.analyze(quiet)
            _ = analyzer.isOnset(flux: baseline.flux)
        }
        let step = analyzer.analyze(loud)
        XCTAssertGreaterThan(step.flux, baseline.flux)
        XCTAssertGreaterThan(step.flux, 0.05)
        XCTAssertTrue(analyzer.isOnset(flux: step.flux))
    }

    func testSilenceProducesNearZeroBands() {
        let analyzer = SpectrumAnalyzer(sampleRate: sampleRate)
        let silence = [Float](repeating: 0, count: analyzer.fftSize)
        var bands = SpectrumBands()
        for _ in 0..<4 {
            bands = analyzer.analyze(silence)
        }
        XCTAssertEqual(bands.rms, 0, accuracy: 1e-3)
        XCTAssertEqual(bands.bass, 0, accuracy: 1e-3)
        XCTAssertEqual(bands.mid, 0, accuracy: 1e-3)
        XCTAssertEqual(bands.treble, 0, accuracy: 1e-3)
        XCTAssertEqual(bands.flux, 0, accuracy: 1e-3)
    }

    func testWrongLengthBufferReturnsZeroBands() {
        let analyzer = SpectrumAnalyzer(sampleRate: sampleRate)
        let short = sineBuffer(frequency: 440, count: analyzer.fftSize / 2)
        XCTAssertEqual(analyzer.analyze(short), SpectrumBands())
    }
}
