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
}
