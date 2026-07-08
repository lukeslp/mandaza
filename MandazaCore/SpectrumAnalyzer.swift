import Foundation
import Accelerate

/// Normalized 0…1 audio measurements for one FFT frame.
/// `flux` is the spectral flux (sum of positive per-bin magnitude
/// increases) versus the previous frame — a rough "how much changed"
/// signal used for onset detection.
public struct SpectrumBands: Equatable, Sendable {
    public var rms: Float
    public var bass: Float
    public var mid: Float
    public var treble: Float
    public var flux: Float

    public init(rms: Float = 0, bass: Float = 0, mid: Float = 0, treble: Float = 0, flux: Float = 0) {
        self.rms = rms
        self.bass = bass
        self.mid = mid
        self.treble = treble
        self.flux = flux
    }
}

/// Pure-Accelerate spectrum analysis: Hann window → forward real FFT →
/// magnitude spectrum → fixed-scale band levels (bass 20–250 Hz,
/// mid 250–2000 Hz, treble 2–8 kHz) plus RMS and spectral flux.
/// Deterministic for a given call sequence, no audio-framework imports.
///
/// NOT thread-safe by design: a single audio-tap caller is expected to
/// feed `analyze(_:)` serially. Flux and onset state live per instance.
public final class SpectrumAnalyzer {
    public let sampleRate: Double
    public let fftSize: Int

    private let fft: vDSP.FFT<DSPSplitComplex>
    private let window: [Float]
    /// Fixed normalization: a full-scale sine concentrates roughly this
    /// much magnitude in its bin after the Hann window's 0.5 coherent
    /// gain and vDSP's packed real-FFT scaling.
    private let referenceMagnitude: Float

    private var windowed: [Float]
    private var realIn: [Float]
    private var imagIn: [Float]
    private var realOut: [Float]
    private var imagOut: [Float]
    private var magnitudes: [Float]
    private var previousMagnitudes: [Float]
    private var fluxScratch: [Float]

    private var fluxHistory: [Float] = []
    private let fluxHistoryLength = 40

    public init(sampleRate: Double, fftSize: Int = 1024) {
        precondition(fftSize >= 64 && fftSize & (fftSize - 1) == 0,
                     "fftSize must be a power of two ≥ 64")
        self.sampleRate = sampleRate
        self.fftSize = fftSize

        let log2n = vDSP_Length(Int(log2(Double(fftSize)).rounded()))
        guard let fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self) else {
            preconditionFailure("vDSP.FFT setup failed for fftSize \(fftSize)")
        }
        self.fft = fft
        self.window = vDSP.window(ofType: Float.self,
                                  usingSequence: .hanningDenormalized,
                                  count: fftSize,
                                  isHalfWindow: false)
        self.referenceMagnitude = Float(fftSize) / 4

        let half = fftSize / 2
        self.windowed = [Float](repeating: 0, count: fftSize)
        self.realIn = [Float](repeating: 0, count: half)
        self.imagIn = [Float](repeating: 0, count: half)
        self.realOut = [Float](repeating: 0, count: half)
        self.imagOut = [Float](repeating: 0, count: half)
        self.magnitudes = [Float](repeating: 0, count: half)
        self.previousMagnitudes = [Float](repeating: 0, count: half)
        self.fluxScratch = [Float](repeating: 0, count: half)
    }

    /// Analyzes exactly `fftSize` mono samples. A buffer of any other
    /// length returns all-zero bands rather than crashing, since audio
    /// taps can deliver short tail buffers. The first call reports
    /// inflated flux (previous frame is silence) by design.
    public func analyze(_ samples: [Float]) -> SpectrumBands {
        guard samples.count == fftSize else { return SpectrumBands() }

        let rms = min(max(vDSP.rootMeanSquare(samples), 0), 1)
        vDSP.multiply(samples, window, result: &windowed)

        let half = fftSize / 2
        windowed.withUnsafeBufferPointer { input in
            realIn.withUnsafeMutableBufferPointer { real in
                imagIn.withUnsafeMutableBufferPointer { imag in
                    var packed = DSPSplitComplex(realp: real.baseAddress!,
                                                 imagp: imag.baseAddress!)
                    input.baseAddress!.withMemoryRebound(to: DSPComplex.self,
                                                         capacity: half) { complex in
                        vDSP_ctoz(complex, 2, &packed, 1, vDSP_Length(half))
                    }
                }
            }
        }

        realIn.withUnsafeBufferPointer { rIn in
            imagIn.withUnsafeBufferPointer { iIn in
                realOut.withUnsafeMutableBufferPointer { rOut in
                    imagOut.withUnsafeMutableBufferPointer { iOut in
                        let input = DSPSplitComplex(realp: UnsafeMutablePointer(mutating: rIn.baseAddress!),
                                                    imagp: UnsafeMutablePointer(mutating: iIn.baseAddress!))
                        var output = DSPSplitComplex(realp: rOut.baseAddress!,
                                                     imagp: iOut.baseAddress!)
                        fft.forward(input: input, output: &output)
                        vDSP.absolute(output, result: &magnitudes)
                    }
                }
            }
        }

        let bass = bandLevel(lowHz: 20, highHz: 250)
        let mid = bandLevel(lowHz: 250, highHz: 2000)
        let treble = bandLevel(lowHz: 2000, highHz: 8000)

        vDSP.subtract(magnitudes, previousMagnitudes, result: &fluxScratch)
        vDSP.clip(fluxScratch, to: 0...Float.greatestFiniteMagnitude, result: &fluxScratch)
        let flux = min(max(vDSP.sum(fluxScratch) / (referenceMagnitude * 2), 0), 1)
        previousMagnitudes = magnitudes

        return SpectrumBands(rms: rms, bass: bass, mid: mid, treble: treble, flux: flux)
    }

    /// Onset when `flux` exceeds 1.6× the running mean of the last
    /// ~40 flux values and that mean is non-trivial. The incoming value
    /// joins the history after the decision so a spike does not dilute
    /// its own detection.
    public func isOnset(flux: Float) -> Bool {
        let mean = fluxHistory.isEmpty
            ? 0
            : fluxHistory.reduce(0, +) / Float(fluxHistory.count)
        let onset = mean > 0.01 && flux > 1.6 * mean

        fluxHistory.append(flux)
        if fluxHistory.count > fluxHistoryLength {
            fluxHistory.removeFirst(fluxHistory.count - fluxHistoryLength)
        }
        return onset
    }

    private func bandLevel(lowHz: Double, highHz: Double) -> Float {
        let binHz = sampleRate / Double(fftSize)
        let low = max(1, Int((lowHz / binHz).rounded(.up)))
        let high = min(magnitudes.count - 1, Int((highHz / binHz).rounded(.down)))
        guard low <= high else { return 0 }
        let mean = vDSP.mean(magnitudes[low...high])
        return min(max(mean / referenceMagnitude, 0), 1)
    }
}
