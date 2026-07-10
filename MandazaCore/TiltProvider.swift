import Foundation
import CoreGraphics
import Observation

/// Pure mapping from device gravity to a layered-parallax offset.
///
/// Uses the gravity vector (not Euler pitch/roll) so upright holding stays
/// away from the attitude singularity that makes roll thrash, and so "flat on
/// the table" can fade the effect out instead of slamming the Y axis.
///
/// - `gravityX`: device +X (right). Positive when the right edge dips.
/// - `gravityY`: device +Y (top). ≈ −1 when upright in portrait, ≈ 0 flat.
/// - `gravityZ`: device +Z (out of screen). 0 upright; −1 face-up flat.
///
/// Returns `.zero` when tilt is `.off`, or when the device is too flat for a
/// stable reading. Offset saturates at a small fraction of the shorter edge
/// (`subtle` ≈ 2%, `pronounced` ≈ 5%). The layer shifts *with* the tilt so
/// rolling the device right nudges the artwork right.
public func tiltOffset(gravityX: Double,
                       gravityY: Double,
                       gravityZ: Double,
                       intensity: ZenTiltIntensity,
                       viewSize: CGSize) -> CGSize {
    let fraction: Double
    switch intensity {
    case .off:        return .zero
    case .subtle:     fraction = 0.02
    case .pronounced: fraction = 0.05
    }

    // Fade out as the phone approaches flat (gravityY → 0 from −1). Below
    // about −0.25 the reading is both less meaningful and more prone to
    // axis-swap noise; at upright (≤ −0.8) the effect is full strength.
    let upright = max(0.0, min(1.0, (-gravityY - 0.25) / 0.55))
    guard upright > 0.001 else { return .zero }

    let maxOffset = fraction * Double(min(viewSize.width, viewSize.height)) * upright
    // Fraction of g at which the parallax reaches its clamp (~23° from upright).
    let reference = 0.40
    let nx = max(-1.0, min(1.0, gravityX / reference))
    let ny = max(-1.0, min(1.0, gravityZ / reference))
    // Shift with the tilt (right dip → artwork moves right).
    return CGSize(width: nx * maxOffset, height: ny * maxOffset)
}

#if os(tvOS) || os(macOS)

/// tvOS (and the macOS unit-test host) have no device-motion sensors: the
/// provider is inert. `offset` never moves off `.zero`, so the parallax layer
/// is a no-op and no CoreMotion symbols are referenced on these platforms.
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
/// Streams device gravity (not Euler attitude), low-pass smooths it, and
/// publishes a clamped `offset` via `tiltOffset`. Gravity avoids the upright
/// gimbal-lock flicker that made the canvas stutter when the phone reclined
/// or lay flat. Runs only while started; `stop()` tears updates down and
/// recentres.
@MainActor
@Observable
public final class TiltProvider {
    public private(set) var offset: CGSize = .zero

    /// Size of the layer being parallaxed; sets the clamp scale. Update this
    /// when the canvas resizes so the offset tracks the current geometry.
    @ObservationIgnored public var viewSize: CGSize = CGSize(width: 1, height: 1)

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var intensity: ZenTiltIntensity = .off
    @ObservationIgnored private var smoothedX = 0.0
    @ObservationIgnored private var smoothedY = -1.0
    @ObservationIgnored private var smoothedZ = 0.0

    public init() {}

    public func start(intensity: ZenTiltIntensity) {
        self.intensity = intensity
        guard intensity != .off else { stop(); return }
        guard motion.isDeviceMotionAvailable else { return }
        guard !motion.isDeviceMotionActive else {
            // Intensity can change while already running; keep the stream.
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let g = data.gravity
            Task { @MainActor [weak self] in
                self?.consume(x: g.x, y: g.y, z: g.z)
            }
        }
    }

    public func stop() {
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
        smoothedX = 0
        smoothedY = -1
        smoothedZ = 0
        offset = .zero
    }

    /// Low-pass smoothing keeps the parallax buttery; raw gravity is still
    /// a little noisy at 60 Hz. Skip publishing sub-pixel changes so SwiftUI
    /// is not invalidated every frame while the phone is still.
    private func consume(x: Double, y: Double, z: Double) {
        guard intensity != .off else { return }
        let a = 0.18
        smoothedX += a * (x - smoothedX)
        smoothedY += a * (y - smoothedY)
        smoothedZ += a * (z - smoothedZ)
        let next = tiltOffset(gravityX: smoothedX,
                              gravityY: smoothedY,
                              gravityZ: smoothedZ,
                              intensity: intensity,
                              viewSize: viewSize)
        if hypot(next.width - offset.width, next.height - offset.height) < 0.25 {
            return
        }
        offset = next
    }
}

#endif
