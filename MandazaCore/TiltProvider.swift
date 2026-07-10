import Foundation
import CoreGraphics
import Observation

/// Pure mapping from device attitude to a layered-parallax offset.
///
/// Returns `.zero` when tilt is `.off`. Otherwise the offset saturates at a
/// small fraction of the view's shorter edge (`subtle` ≈ 2%, `pronounced` ≈
/// 5%), so the parallax stays a whisper rather than sliding the mandala off
/// screen. The offset runs *opposite* to the tilt — rolling the device right
/// nudges the artwork left, which reads as depth. Kept free of any CoreMotion
/// type so it unit-tests on every platform.
public func tiltOffset(pitch: Double,
                       roll: Double,
                       intensity: ZenTiltIntensity,
                       viewSize: CGSize) -> CGSize {
    let fraction: Double
    switch intensity {
    case .off:        return .zero
    case .subtle:     fraction = 0.02
    case .pronounced: fraction = 0.05
    }
    let maxOffset = fraction * Double(min(viewSize.width, viewSize.height))
    // Attitude at which the parallax reaches its clamp (~26°). Beyond this the
    // offset holds at the max instead of racing away.
    let reference = 0.45
    let nx = max(-1.0, min(1.0, roll / reference))
    let ny = max(-1.0, min(1.0, pitch / reference))
    // Mandala shifts against the tilt.
    return CGSize(width: -nx * maxOffset, height: -ny * maxOffset)
}

#if os(tvOS)

/// tvOS has no motion sensors: the provider is inert. `offset` never moves off
/// `.zero`, so the parallax layer is a no-op and no CoreMotion symbols are
/// referenced on this platform.
@MainActor
@Observable
public final class TiltProvider {
    public private(set) var offset: CGSize = .zero

    /// Size of the layer being parallaxed; sets the clamp scale. No-op on tvOS.
    @ObservationIgnored public var viewSize: CGSize = CGSize(width: 1, height: 1)

    public init() {}
    public func start(intensity: ZenTiltIntensity) {}
    public func stop() {}
}

#else

import CoreMotion

/// CoreMotion-backed parallax source for iPhone and Apple Watch.
///
/// Streams device-motion attitude, low-pass smooths it, and publishes a
/// clamped `offset` via `tiltOffset`. Runs only while started (Zen visible +
/// intensity ≠ off); `stop()` tears the motion updates down and recentres so
/// nothing drifts while idle.
@MainActor
@Observable
public final class TiltProvider {
    public private(set) var offset: CGSize = .zero

    /// Size of the layer being parallaxed; sets the clamp scale. Update this
    /// when the canvas resizes so the offset tracks the current geometry.
    @ObservationIgnored public var viewSize: CGSize = CGSize(width: 1, height: 1)

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var intensity: ZenTiltIntensity = .off
    @ObservationIgnored private var smoothedPitch = 0.0
    @ObservationIgnored private var smoothedRoll = 0.0

    public init() {}

    public func start(intensity: ZenTiltIntensity) {
        self.intensity = intensity
        guard intensity != .off else { stop(); return }
        guard motion.isDeviceMotionAvailable else { return }
        guard !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let pitch = data.attitude.pitch
            let roll = data.attitude.roll
            Task { @MainActor [weak self] in
                self?.consume(pitch: pitch, roll: roll)
            }
        }
    }

    public func stop() {
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
        smoothedPitch = 0
        smoothedRoll = 0
        offset = .zero
    }

    /// Low-pass smoothing keeps the parallax buttery; a raw attitude feed is
    /// too jittery to ride a layer on.
    private func consume(pitch: Double, roll: Double) {
        guard intensity != .off else { return }
        let a = 0.15
        smoothedPitch += a * (pitch - smoothedPitch)
        smoothedRoll += a * (roll - smoothedRoll)
        offset = tiltOffset(pitch: smoothedPitch,
                            roll: smoothedRoll,
                            intensity: intensity,
                            viewSize: viewSize)
    }
}

#endif
