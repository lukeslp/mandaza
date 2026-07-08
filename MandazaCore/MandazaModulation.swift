import Foundation
import Observation

/// Pre-smoothed, normalized modulation values (audio-reactive or otherwise)
/// that `MandazaCanvas` maps onto stroke width, glow, and palette phase.
/// All band values are 0...1; `colorPhaseMs` is an accumulated phase advance
/// in milliseconds added to the palette-pulse clock.
public struct MandazaModulation: Equatable, Sendable {
    public var level: Double
    public var bass: Double
    public var mid: Double
    public var treble: Double
    public var beatPulse: Double
    public var colorPhaseMs: Double

    public init(level: Double = 0,
                bass: Double = 0,
                mid: Double = 0,
                treble: Double = 0,
                beatPulse: Double = 0,
                colorPhaseMs: Double = 0) {
        self.level = level
        self.bass = bass
        self.mid = mid
        self.treble = treble
        self.beatPulse = beatPulse
        self.colorPhaseMs = colorPhaseMs
    }

    public static let zero = MandazaModulation()
}

/// Observable bridge a producer (e.g. an audio analyzer) writes into and
/// `MandazaCanvas` reads each frame. Reads inside the TimelineView closure
/// register an Observation dependency, so frames pick up fresh values
/// without extra plumbing. `isActive == false` means "render exactly as
/// if no modulation existed".
@Observable @MainActor
public final class MandazaModulationSource {
    public var modulation: MandazaModulation = .zero
    public var isActive: Bool = false
    public init() {}

    #if DEBUG
    @ObservationIgnored private var demoTimer: Timer?

    /// Screenshot/demo only: drives a synthetic, pleasant modulation so
    /// Music Mode can be captured without live audio input. Never compiled
    /// into release builds.
    public func startDemo() {
        isActive = true
        let start = Date()
        demoTimer?.invalidate()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let t = Date().timeIntervalSince(start)
            Task { @MainActor in
                self.modulation = MandazaModulation(
                    level: 0.55 + 0.25 * sin(t * 1.7),
                    bass: 0.6 + 0.3 * sin(t * 1.1),
                    mid: 0.45 + 0.3 * sin(t * 2.3 + 1),
                    treble: 0.4 + 0.3 * sin(t * 3.1 + 2),
                    beatPulse: max(0, sin(t * 2.0)),
                    colorPhaseMs: t * 400)
            }
        }
    }

    public func stopDemo() {
        demoTimer?.invalidate()
        demoTimer = nil
        isActive = false
        modulation = .zero
    }
    #endif
}
