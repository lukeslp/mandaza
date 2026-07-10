import SwiftUI
import Foundation

// MARK: - Music reactivity (pure helpers)

/// Clamp to the unit interval.
@inline(__always) func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }

/// Animation-speed multiplier from instantaneous loudness, scaled by the
/// user's `reactivity`. Silence (`level` 0) or `reactivity` 0 returns 1.0
/// (no speed-up). At full loudness and reactivity 1 the animation clock
/// advances 2.5× real time. `level` is clamped to 0…1 so the clock never
/// reverses or runs away on an out-of-range reading.
func speedFactor(level: Double, reactivity r: Double) -> Double {
    1 + r * 1.5 * clamp01(level)
}

/// Per-beat scale pump applied about the canvas center, scaled by
/// `reactivity`. `reactivity` 0 is inert (1.0). At the default reactivity
/// (0.35) a full beat peaks near 1.06×; at maximum reactivity (1.0) it peaks
/// near 1.30×. `beatEnv` is a 0…1 decaying beat envelope. The pump only ever
/// grows the mandala — it never pulls it below its resting size.
///
/// The `pow(r, 1.5)` shaping hits both design targets (≈1.06 at 0.35, 1.30
/// at 1.0) while staying monotonic and never dipping below 1.0 for any
/// reactivity in 0…1 — a plain linear `0.06 + r*0.24` blend overshoots the
/// gentle-default target and can shrink the art at low reactivity.
func scaleThrob(beatEnv: Double, reactivity r: Double) -> Double {
    guard r > 0 else { return 1 }
    return 1 + 0.30 * pow(clamp01(r), 1.5) * clamp01(beatEnv)
}

/// Animation cadence for `MandazaCanvas`.
///
/// iOS and tvOS use `.smooth` (display-link, pauses under Always-On dimming).
/// watchOS requests a throttled `.interval` cadence to protect battery, and
/// `.paused` when the app is backgrounded / the wrist is down.
public enum MandazaCadence: Equatable {
    /// Display-link cadence; pauses automatically under Always-On luminance reduction.
    case smooth
    /// Fixed periodic cadence in seconds (e.g. `1.0 / 24`). Pauses under Always-On.
    case interval(Double)
    /// Frozen — no advancement. For background / inactive scene phases.
    case paused
}

/// SwiftUI Canvas + TimelineView host for the live, animated mandaza.
/// Owns one engine instance and an animation clock. Re-creates the engine
/// when its size or seed changes.
public struct MandazaCanvas: View {
    let size: CGSize
    let seed: UUID
    let paletteId: String
    let config: EngineConfig
    let cadence: MandazaCadence
    /// Per-axis zoom applied at draw time to crop the hex grid's natural margin
    /// so the mandala reaches the edges. (1, 1) = no zoom. The grid is still
    /// built at the real screen size (so cell density is unchanged); this only
    /// scales the rendered drawing about the center and clips the empty border.
    let fill: CGSize
    /// User-facing music-reactivity intensity (0…1). Scales the loudness
    /// speed-up, the per-beat scale-throb, and the beat glow burst. 0 renders
    /// identically to a non-reactive canvas even while a modulation source is
    /// active. Only has a visible effect when `modulationSource` is feeding.
    let reactivity: Double
    /// Optional live modulation feed (audio-reactive, etc.). Read per-frame
    /// inside the timeline closure; nil or inactive renders identically to
    /// an unmodulated canvas.
    let modulationSource: MandazaModulationSource?
    /// Optional tilt-parallax source. Read inside the Canvas draw path (not
    /// via Observation) so motion samples never invalidate this TimelineView.
    /// Per-stroke luminance scales the offset for layered depth.
    let parallaxSource: TiltProvider?
    /// How strongly luminance separates near/far layers (0…1).
    let parallaxDepthContrast: Double
    /// When true, darker strokes travel more (nearer).
    let parallaxInvertDepth: Bool
    /// Ground + stroke shadow language (void glow vs paper ink).
    let theme: CanvasTheme

    /// Fires `true` when all loops finish drawing, `false` when a new pattern
    /// starts. Parents use this to schedule auto-regenerate in Zen mode.
    var onIdleChange: ((Bool) -> Void)? = nil

    @State private var engine = MandazaEngine()
    @State private var built = false
    @State private var builtSize: CGSize = .zero
    @State private var firstTimestamp: Date? = nil
    @State private var wasIdle: Bool? = nil
    @State private var lastAdvanceTimestamp: Date? = nil
    /// Warped animation clock (ms). Advances by `real dt × speedFactor` each
    /// frame so loud music quickens the mandala without disturbing geometry.
    /// Equals real elapsed time when reactivity/level is 0.
    @State private var animMs: Double = 0
    /// Decaying 0…1 beat envelope (~250 ms release) driving the scale-throb
    /// and glow burst. Snaps up on a fresh beat, eases down between.
    @State private var beatEnv: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    public init(size: CGSize,
                seed: UUID,
                paletteId: String,
                config: EngineConfig,
                cadence: MandazaCadence = .smooth,
                fill: CGSize = CGSize(width: 1, height: 1),
                reactivity: Double = 0.35,
                onIdleChange: ((Bool) -> Void)? = nil,
                modulationSource: MandazaModulationSource? = nil,
                parallaxSource: TiltProvider? = nil,
                parallaxDepthContrast: Double = 1,
                parallaxInvertDepth: Bool = false,
                theme: CanvasTheme = .void) {
        self.size = size
        self.seed = seed
        self.paletteId = paletteId
        self.config = config
        self.cadence = cadence
        self.fill = fill
        self.reactivity = reactivity
        self.onIdleChange = onIdleChange
        self.modulationSource = modulationSource
        self.parallaxSource = parallaxSource
        self.parallaxDepthContrast = parallaxDepthContrast
        self.parallaxInvertDepth = parallaxInvertDepth
        self.theme = theme
    }

    public var body: some View {
        Group {
            switch cadence {
            case .smooth:
                timeline(.animation(paused: luminanceReduced))
            case .interval(let seconds):
                // Honor Always-On dimming even in throttled mode.
                if luminanceReduced {
                    timeline(.animation(paused: true))
                } else {
                    timeline(.periodic(from: .now, by: seconds))
                }
            case .paused:
                timeline(.animation(paused: true))
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        // Measure the ACTUAL rendered size and build the engine from it, so the
        // grid (and the overscan center-crop) match the Canvas exactly. Relying
        // on the passed-in `size` can disagree with the real Canvas size on
        // watchOS and push the pattern off-frame.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { updateSize(geo.size) }
                    .onChange(of: geo.size) { _, s in updateSize(s) }
            }
        )
        .onChange(of: seed)      { _, _ in rebuild() }
        .onChange(of: paletteId) { _, new in engine.paletteId = new }
        .onChange(of: config)    { _, new in engine.config = new }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced && built { engine.completeAllPaths() }
        }
    }

    private func updateSize(_ s: CGSize) {
        guard s.width > 1, s.height > 1, s != builtSize else { return }
        builtSize = s
        rebuild(render: s)
    }

    @ViewBuilder
    private func timeline<S: TimelineSchedule>(_ schedule: S) -> some View {
        TimelineView(schedule) { timeline in
            // Reading these here registers the Observation dependency so
            // frames pick up fresh modulation values. The warped `animMs`
            // clock and `beatEnv` are advanced in `advance(now:)` on each
            // timeline tick; drawing them one tick behind is imperceptible.
            let mod = (modulationSource?.isActive == true) ? modulationSource?.modulation : nil
            Canvas(opaque: true,
                   colorMode: .extendedLinear,
                   rendersAsynchronously: false) { ctx, canvasSize in
                drawScene(in: &ctx, size: canvasSize, timeMs: animMs, mod: mod)
            }
            .onChange(of: timeline.date) { _, now in
                advance(now: now)
            }
        }
    }

    private func rebuild(render: CGSize? = nil) {
        let r = render ?? (builtSize == .zero ? size : builtSize)
        engine.config = config
        engine.paletteId = paletteId
        let ok = engine.regenerate(width: Double(r.width),
                                   height: Double(r.height),
                                   seed: seed.uuidString)
        built = ok
        firstTimestamp = nil
        wasIdle = nil
        lastAdvanceTimestamp = nil
        animMs = 0
        beatEnv = 0
        if ok && reduceMotion {
            engine.completeAllPaths()
        }
    }

    private func advance(now: Date) {
        guard built else { return }
        var dtSec = 0.0
        if let last = lastAdvanceTimestamp {
            dtSec = now.timeIntervalSince(last)
            if dtSec < 0.0005 { return }
            // Absorb long stalls (Always-On dimming, wrist-down, backgrounding)
            // by treating the gap as a single frame, so the warped clock stays
            // continuous and the animation doesn't lurch ahead on resume.
            // Normal per-frame gaps are well under this threshold.
            if dtSec > 1.0 { dtSec = 1.0 / 60.0 }
        }
        lastAdvanceTimestamp = now
        if firstTimestamp == nil {
            firstTimestamp = now
            dtSec = 0
        }

        // Live modulation (nil when no source / inactive → identity behavior).
        let mod = (modulationSource?.isActive == true) ? modulationSource?.modulation : nil

        // Loudness warps the animation clock; a decaying beat envelope drives
        // the scale-throb + glow burst. Both collapse to identity at silence
        // or when reactivity is 0.
        let level = mod?.level ?? 0
        animMs += dtSec * 1000 * speedFactor(level: level, reactivity: reactivity)
        // ~250 ms release: snap up on a fresh beat, ease down between beats.
        let pulse = clamp01(mod?.beatPulse ?? 0)
        beatEnv = max(beatEnv * exp(-dtSec / 0.25), pulse)

        let alive = engine.advance(timeMs: animMs)
        let idle = !alive
        if wasIdle != idle {
            wasIdle = idle
            onIdleChange?(idle)
        }
    }

    private func drawScene(in ctx: inout GraphicsContext, size: CGSize, timeMs: Double,
                           mod: MandazaModulation?) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .color(BL.canvasGround(for: theme)))
        guard built else { return }

        // Zoom about the center to crop the grid's natural margin so the
        // mandala reaches the edges (cells keep their on-screen size).
        if fill.width != 1 || fill.height != 1 {
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.scaleBy(x: fill.width, y: fill.height)
            ctx.translateBy(x: -size.width / 2, y: -size.height / 2)
        }

        // Music beat-throb: pump the whole drawing about center on each beat.
        // A presentation-only transform — geometry (loop paths, grid) is
        // untouched, so the mandala stays stable. Identity at reactivity 0
        // or between beats (`beatEnv` 0).
        let throb = scaleThrob(beatEnv: beatEnv, reactivity: reactivity)
        if throb != 1 {
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.scaleBy(x: throb, y: throb)
            ctx.translateBy(x: -size.width / 2, y: -size.height / 2)
        }

        let glowRadius = engine.radius / 5
        var glowScale = min(max(config.glowStrength ?? 1.0, 0.18), 1.0)
        var strokeWidth = (engine.radius / 30) * config.lineWidth
        var colorTimeMs = timeMs
        var shadowOpacity = 0.55 + 0.30 * glowScale
        if let mod {
            strokeWidth *= min(max(1 + 0.30 * mod.level + 0.20 * mod.beatPulse, 1.0), 1.55)
            glowScale = min(max(glowScale + 0.40 * mod.bass, 0.18), 1.0)
            shadowOpacity = min(0.95, 0.55 + 0.30 * glowScale + 0.12 * mod.beatPulse)
            colorTimeMs = timeMs + mod.colorPhaseMs
        }
        // Beat glow burst, scaled by reactivity. `beatEnv` is 0 at silence and
        // between beats, so this is inert unless a beat is decaying.
        if reactivity > 0 && beatEnv > 0.001 {
            shadowOpacity = min(0.98, shadowOpacity + reactivity * 0.2 * beatEnv)
        }

        // Read tilt without Observation — TimelineView already redraws each
        // frame, so parallax stays live without invalidating this view tree.
        let parallax = parallaxSource?.offset ?? .zero

        // Dark (far) first, bright (near) last so nearer strokes sit on top.
        // (Invert depth flips which luminance is nearer.)
        let strokes: [(path: Path, color: Color, depth: Double)] = engine.loops.map { loop in
            let cg = engine.color(for: loop, timeMs: colorTimeMs)
            let lum = relativeLuminance(cg)
            return (Path(engine.currentPath(for: loop)),
                    Color(cgColor: cg),
                    parallaxDepth(luminance: lum,
                                  contrast: parallaxDepthContrast,
                                  invert: parallaxInvertDepth))
        }.sorted { $0.depth < $1.depth }

        let paperTheme = theme == .paper
        for stroke in strokes {
            var layer = ctx
            if parallax != .zero {
                layer.translateBy(x: parallax.width * stroke.depth,
                                  y: parallax.height * stroke.depth)
            }
            if paperTheme {
                // Soft ink contact shadow — depth cue on parchment. Stronger
                // when Glow is on; always a whisper so strokes lift off paper.
                let inkOpacity = config.glow
                    ? min(0.55, 0.22 + 0.28 * glowScale)
                    : 0.16
                let inkRadius = config.glow
                    ? glowRadius * 0.55 * glowScale
                    : glowRadius * 0.22
                layer.addFilter(.shadow(color: BL.ink.opacity(inkOpacity),
                                        radius: inkRadius,
                                        x: 0,
                                        y: inkRadius * 0.35))
                if config.glow {
                    // Colored bloom under the ink shadow for a print-shop feel.
                    layer.addFilter(.shadow(color: stroke.color.opacity(shadowOpacity * 0.45),
                                            radius: glowRadius * glowScale * 0.7))
                }
            } else if config.glow {
                layer.addFilter(.shadow(color: stroke.color.opacity(shadowOpacity),
                                        radius: glowRadius * glowScale))
            } else if let mod, mod.bass > 0.001 || mod.level > 0.001 {
                // Transient audio glow when the user has glow off: subtle,
                // driven only by live energy, and gone when the signal is.
                layer.addFilter(.shadow(color: stroke.color.opacity(0.35 * mod.level),
                                        radius: glowRadius * 0.30 * mod.bass))
            }
            layer.stroke(stroke.path,
                         with: .color(stroke.color),
                         style: StrokeStyle(lineWidth: strokeWidth,
                                            lineCap: .round,
                                            lineJoin: .round))
        }
    }
}
