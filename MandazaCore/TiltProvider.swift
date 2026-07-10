import Foundation
import CoreGraphics

/// Maximum travel as a fraction of the shorter view edge when amount is 1.0.
public let tiltMaxTravelFraction: Double = 0.48

/// Pure mapping from device gravity to a layered-parallax offset.
///
/// Uses the gravity vector (not Euler pitch/roll) so upright holding stays
/// away from the attitude singularity that made roll thrash.
///
/// - `gravityX`: device +X (right). Positive when the right edge dips.
/// - `gravityY`: device +Y (top). ≈ −1 when upright in portrait, ≈ 0 flat.
/// - `gravityZ`: device +Z (out of screen). 0 upright; −1 face-up flat.
///
/// `amount` is 0…1 travel strength (0 ⇒ no motion). Offset saturates at
/// `amount × tiltMaxTravelFraction` of the shorter edge. The layer shifts
/// *with* the tilt so rolling the device right nudges the artwork right.
/// Per-stroke luminance then scales that travel in the canvas.
///
/// No upright-only fade: a normal reading angle already reclines past “perfect
/// vertical,” and fading there made parallax feel frozen. Face-up flat simply
/// parks at a stable clamped offset (gravity is steady there).
public func tiltOffset(gravityX: Double,
                       gravityY: Double,
                       gravityZ: Double,
                       amount: Double,
                       axes: ZenTiltAxes = .both,
                       viewSize: CGSize) -> CGSize {
    let a = min(1, max(0, amount))
    guard a > 0.001 else { return .zero }

    let maxOffset = a * tiltMaxTravelFraction * Double(min(viewSize.width, viewSize.height))
    // Fraction of g at which the parallax reaches its clamp (~16°). Lower than
    // a strict upright reference so everyday tilts use more of the travel.
    let reference = 0.28
    var nx = max(-1.0, min(1.0, gravityX / reference))
    // Longitudinal: deviation from upright. Upright ≈ (0, −1, 0); reclining
    // toward face-up grows −Z. Using Z alone keeps left/right on X.
    var ny = max(-1.0, min(1.0, gravityZ / reference))
    switch axes {
    case .both: break
    case .horizontal: ny = 0
    case .vertical:   nx = 0
    }
    return CGSize(width: nx * maxOffset, height: ny * maxOffset)
}

/// Legacy intensity → continuous amount. Kept so older call sites and tests
/// keep their exact travel fractions (subtle 18%, pronounced 42%).
public func tiltAmount(for intensity: ZenTiltIntensity) -> Double {
    switch intensity {
    case .off:        return 0
    case .subtle:     return 0.18 / tiltMaxTravelFraction
    case .pronounced: return 0.42 / tiltMaxTravelFraction
    }
}

public func tiltOffset(gravityX: Double,
                       gravityY: Double,
                       gravityZ: Double,
                       intensity: ZenTiltIntensity,
                       viewSize: CGSize) -> CGSize {
    tiltOffset(gravityX: gravityX,
               gravityY: gravityY,
               gravityZ: gravityZ,
               amount: tiltAmount(for: intensity),
               axes: .both,
               viewSize: viewSize)
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

/// Maps luminance to a parallax depth multiplier.
///
/// - `contrast` 0…1: 0 flattens all strokes to mid-depth; 1 uses full near/far.
/// - `invert`: when true, darker strokes sit nearer (more travel).
public func parallaxDepth(luminance: Double,
                          contrast: Double = 1,
                          invert: Bool = false) -> Double {
    var t = min(1, max(0, luminance))
    if invert { t = 1 - t }
    let c = min(1, max(0, contrast))
    let layered = 0.5 + (t - 0.5) * c
    return 0.22 + 0.78 * layered
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
    public func start(amount: Double, axes: ZenTiltAxes = .both) {}
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
    private var amount: Double = 0
    private var axes: ZenTiltAxes = .both
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
        start(amount: tiltAmount(for: intensity), axes: .both)
    }

    public func start(amount: Double, axes: ZenTiltAxes = .both) {
        self.amount = min(1, max(0, amount))
        self.axes = axes
        guard self.amount > 0.001 else { stop(); return }
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
        amount = 0
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
        smoothedX = 0
        smoothedY = -1
        smoothedZ = 0
        publish(.zero)
    }

    private func consume(x: Double, y: Double, z: Double) {
        guard amount > 0.001 else { return }
        let a = 0.18
        smoothedX += a * (x - smoothedX)
        smoothedY += a * (y - smoothedY)
        smoothedZ += a * (z - smoothedZ)
        let next = tiltOffset(gravityX: smoothedX,
                              gravityY: smoothedY,
                              gravityZ: smoothedZ,
                              amount: amount,
                              axes: axes,
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
