import Foundation
import CoreGraphics

/// Maximum travel as a fraction of the shorter view edge when amount is 1.0.
/// Kept modest so everyday tilts read as depth without cropping the OFF frame.
public let tiltMaxTravelFraction: Double = 0.12

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
    // Fraction of g at which each axis reaches its clamp. Horizontal (roll)
    // swings gravityX far for a small wrist twist, so it needs a *larger*
    // reference than the longitudinal axis or it reads disproportionately
    // strong. These pull the two axes into visual balance.
    let referenceX = 0.46
    let referenceZ = 0.26
    var nx = max(-1.0, min(1.0, gravityX / referenceX))
    // Longitudinal: deviation from upright. Upright ≈ (0, −1, 0); reclining
    // toward face-up grows −Z. Using Z alone keeps left/right on X.
    var ny = max(-1.0, min(1.0, gravityZ / referenceZ))
    switch axes {
    case .both: break
    case .horizontal: ny = 0
    case .vertical:   nx = 0
    }
    return CGSize(width: nx * maxOffset, height: ny * maxOffset)
}

/// Faint Zen-mode ambient sway. Dual incommensurate sines per axis so the
/// loop is long enough to read as endless drift rather than a short cycle.
/// `amount` is the same 0…1 travel strength as tilt; sway peaks at ~30% of
/// that max travel so it shows depth layers without competing with real tilts.
public func ambientParallaxOffset(time: TimeInterval,
                                  amount: Double,
                                  axes: ZenTiltAxes = .both,
                                  viewSize: CGSize) -> CGSize {
    let a = min(1, max(0, amount))
    guard a > 0.001 else { return .zero }
    let maxTravel = a * tiltMaxTravelFraction * 0.30
        * Double(min(viewSize.width, viewSize.height))
    let twoPi = Double.pi * 2
    // Coprime-ish periods (seconds): 13×17×19×23 ≈ 97k s before near-repeat.
    var x = sin(time * twoPi / 13.0) * 0.62 + sin(time * twoPi / 23.0 + 0.9) * 0.38
    var y = sin(time * twoPi / 17.0 + 1.2) * 0.58 + sin(time * twoPi / 29.0 + 0.35) * 0.42
    switch axes {
    case .both: break
    case .horizontal: y = 0
    case .vertical:   x = 0
    }
    return CGSize(width: x * maxTravel, height: y * maxTravel)
}

/// Legacy intensity → continuous amount. Subtle ≈ half travel, pronounced = full.
public func tiltAmount(for intensity: ZenTiltIntensity) -> Double {
    switch intensity {
    case .off:        return 0
    case .subtle:     return 0.5
    case .pronounced: return 1.0
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
    /// When true (Zen + parallax), a faint long-period sway is mixed into
    /// `offset` so depth layers keep drifting while the device is still.
    public var ambientSway: Bool = false

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

    /// When true (Zen + parallax), mix a faint long-period sway into `offset`
    /// so luminance depth keeps drifting while the device is still.
    public var ambientSway: Bool = false

    private let motion = CMMotionManager()
    private var amount: Double = 0
    private var axes: ZenTiltAxes = .both
    private var smoothedX = 0.0
    private var smoothedY = -1.0
    private var smoothedZ = 0.0
    // Slow "washout" baseline. The offset is computed from how far the current
    // pose has *moved* from this baseline, and the baseline eases toward the
    // current pose (~1 s). So parallax reacts to tilts but recenters to
    // whatever angle you actually hold the phone — it never sits parked
    // off-center when reclined.
    private var baseX = 0.0
    private var baseZ = 0.0
    private var needsRecenter = true
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
        needsRecenter = true
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
        baseX = 0
        baseZ = 0
        needsRecenter = true
        publish(.zero)
    }

    private func consume(x: Double, y: Double, z: Double) {
        guard amount > 0.001 else { return }

        // On (re)start, snap smoothing + baseline to the first real pose so
        // the layer begins dead-centered wherever the phone is held.
        if needsRecenter {
            smoothedX = x; smoothedY = y; smoothedZ = z
            baseX = x; baseZ = z
            needsRecenter = false
            publish(.zero)
            return
        }

        // Higher = more responsive. 0.18 felt "underwater"; 0.4 tracks the
        // wrist closely while still filtering hand tremor at 60 Hz.
        let a = 0.4
        smoothedX += a * (x - smoothedX)
        smoothedY += a * (y - smoothedY)
        smoothedZ += a * (z - smoothedZ)

        // Washout: baseline eases toward the current pose (~1 s at 60 Hz), so
        // a held angle recenters instead of parking the art off-screen.
        let b = 0.016
        baseX += b * (smoothedX - baseX)
        baseZ += b * (smoothedZ - baseZ)

        let tilt = tiltOffset(gravityX: smoothedX - baseX,
                              gravityY: smoothedY,
                              gravityZ: smoothedZ - baseZ,
                              amount: amount,
                              axes: axes,
                              viewSize: viewSize)
        var next = tilt
        if ambientSway {
            // Wall-clock sway so depth layers keep drifting at rest. Mixed
            // after washout so it never parks the art off-center.
            let amb = ambientParallaxOffset(time: Date().timeIntervalSinceReferenceDate,
                                            amount: amount,
                                            axes: axes,
                                            viewSize: viewSize)
            next = CGSize(width: tilt.width + amb.width,
                          height: tilt.height + amb.height)
        }
        // Sub-pixel skip while still — but never while ambient sway is on,
        // or the slow sine steps (~0.1pt/frame) would freeze the drift.
        if !ambientSway,
           hypot(next.width - offset.width, next.height - offset.height) < 0.25 {
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
