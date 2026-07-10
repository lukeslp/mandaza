import Foundation
import CoreGraphics

/// Pure mapping from device gravity to a layered-parallax offset.
///
/// Uses the gravity vector (not Euler pitch/roll) so upright holding stays
/// away from the attitude singularity that made roll thrash.
///
/// - `gravityX`: device +X (right). Positive when the right edge dips.
/// - `gravityY`: device +Y (top). ≈ −1 when upright in portrait, ≈ 0 flat.
/// - `gravityZ`: device +Z (out of screen). 0 upright; −1 face-up flat.
///
/// Returns `.zero` when tilt is `.off`. Offset saturates at a small fraction
/// of the shorter edge (`subtle` ≈ 2%, `pronounced` ≈ 5%). The layer shifts
/// *with* the tilt so rolling the device right nudges the artwork right.
///
/// No upright-only fade: a normal reading angle already reclines past “perfect
/// vertical,” and fading there made parallax feel frozen. Face-up flat simply
/// parks at a stable clamped offset (gravity is steady there).
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

    let maxOffset = fraction * Double(min(viewSize.width, viewSize.height))
    // Fraction of g at which the parallax reaches its clamp (~23°).
    let reference = 0.40
    let nx = max(-1.0, min(1.0, gravityX / reference))
    // Longitudinal: deviation from upright. Upright ≈ (0, −1, 0); reclining
    // toward face-up grows −Z. Using Z alone keeps left/right on X.
    let ny = max(-1.0, min(1.0, gravityZ / reference))
    return CGSize(width: nx * maxOffset, height: ny * maxOffset)
}

#if os(tvOS) || os(macOS)

/// tvOS (and the macOS unit-test host) have no device-motion sensors: the
/// provider is inert. `offset` never moves off `.zero`, so the parallax layer
/// is a no-op and no CoreMotion symbols are referenced on these platforms.
@MainActor
public final class TiltProvider {
    public private(set) var offset: CGSize = .zero
    public var viewSize: CGSize = CGSize(width: 1, height: 1)

    public init() {}
    public func start(intensity: ZenTiltIntensity) {}
    public func stop() {}

    @discardableResult
    public func addListener(_ listener: @escaping (CGSize) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = listener
        listener(offset)
        return id
    }

    public func removeListener(_ id: UUID) {
        listeners.removeValue(forKey: id)
    }

    private var listeners: [UUID: (CGSize) -> Void] = [:]
}

#else

import CoreMotion

/// CoreMotion-backed parallax source for iPhone and Apple Watch.
///
/// Streams device gravity, low-pass smooths it, and publishes offsets to
/// registered listeners. Intentionally **not** `@Observable`: SwiftUI must not
/// rebuild the live `TimelineView` canvas on every motion sample. UIKit hosts
/// apply `CGAffineTransform` from the listener callbacks instead.
@MainActor
public final class TiltProvider {
    public private(set) var offset: CGSize = .zero

    /// Size of the layer being parallaxed; sets the clamp scale. Update this
    /// when the canvas resizes so the offset tracks the current geometry.
    public var viewSize: CGSize = CGSize(width: 1, height: 1)

    private let motion = CMMotionManager()
    private var intensity: ZenTiltIntensity = .off
    private var smoothedX = 0.0
    private var smoothedY = -1.0
    private var smoothedZ = 0.0
    private var listeners: [UUID: (CGSize) -> Void] = [:]

    public init() {}

    /// Register for offset updates. The listener is invoked immediately with
    /// the current offset, then on each motion publish. Returns an id for
    /// `removeListener`.
    @discardableResult
    public func addListener(_ listener: @escaping (CGSize) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = listener
        listener(offset)
        return id
    }

    public func removeListener(_ id: UUID) {
        listeners.removeValue(forKey: id)
    }

    public func start(intensity: ZenTiltIntensity) {
        self.intensity = intensity
        guard intensity != .off else { stop(); return }
        guard motion.isDeviceMotionAvailable else { return }
        guard !motion.isDeviceMotionActive else { return }
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
        publish(.zero)
    }

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
        // Sub-pixel skip: avoid transform spam while the phone is still.
        if hypot(next.width - offset.width, next.height - offset.height) < 0.25 {
            return
        }
        publish(next)
    }

    private func publish(_ next: CGSize) {
        offset = next
        for listener in listeners.values {
            listener(next)
        }
    }
}

#endif
