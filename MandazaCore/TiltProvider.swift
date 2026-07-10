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
/// Returns `.zero` when tilt is `.off`. Offset saturates at a fraction of the
/// shorter edge (`subtle` ≈ 18%, `pronounced` ≈ 42%) so depth reads clearly.
/// The layer shifts *with* the tilt so rolling the device right nudges the
/// artwork right. Per-stroke luminance then scales that travel in the canvas
/// (brighter nearer, darker farther).
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
    case .subtle:     fraction = 0.18
    case .pronounced: fraction = 0.42
    }

    let maxOffset = fraction * Double(min(viewSize.width, viewSize.height))
    // Fraction of g at which the parallax reaches its clamp (~16°). Lower than
    // a strict upright reference so everyday tilts use more of the travel.
    let reference = 0.28
    let nx = max(-1.0, min(1.0, gravityX / reference))
    // Longitudinal: deviation from upright. Upright ≈ (0, −1, 0); reclining
    // toward face-up grows −Z. Using Z alone keeps left/right on X.
    let ny = max(-1.0, min(1.0, gravityZ / reference))
    return CGSize(width: nx * maxOffset, height: ny * maxOffset)
}

/// Relative luminance in 0…1 for an sRGB (or convertible) `CGColor`.
/// Used to scale per-stroke parallax: brighter → nearer → more travel.
public func relativeLuminance(_ color: CGColor) -> Double {
    guard let rgb = color.converted(to: CGColorSpaceCreateDeviceRGB(),
                                    intent: .defaultIntent,
                                    options: nil),
          let c = rgb.components, c.count >= 3 else {
        return 0.5
    }
    func linearize(_ u: CGFloat) -> Double {
        let x = Double(u)
        return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
    }
    let r = linearize(c[0]), g = linearize(c[1]), b = linearize(c[2])
    return min(1, max(0, 0.2126 * r + 0.7152 * g + 0.0722 * b))
}

/// Maps luminance to a parallax depth multiplier. Dark strokes sit farther
/// back (less shift); bright strokes sit nearer (more shift).
public func parallaxDepth(luminance: Double) -> Double {
    let lum = min(1, max(0, luminance))
    return 0.22 + 0.78 * lum
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
