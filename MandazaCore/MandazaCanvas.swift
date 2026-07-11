import SwiftUI

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
    let seed: String
    let paletteId: String
    let config: EngineConfig
    let cadence: MandazaCadence
    /// Per-axis zoom applied at draw time to crop the hex grid's natural margin
    /// so the mandala reaches the edges. (1, 1) = no zoom. The grid is still
    /// built at the real screen size (so cell density is unchanged); this only
    /// scales the rendered drawing about the center and clips the empty border.
    let fill: CGSize

    /// Fires `true` when all loops finish drawing, `false` when a new pattern
    /// starts. Parents use this to schedule auto-regenerate in Zen mode.
    var onIdleChange: ((Bool) -> Void)? = nil

    @State private var engine = MandazaEngine()
    @State private var built = false
    @State private var builtSize: CGSize = .zero
    @State private var firstTimestamp: Date? = nil
    @State private var wasIdle: Bool? = nil
    @State private var lastAdvanceTimestamp: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    public init(size: CGSize,
                seed: String,
                paletteId: String,
                config: EngineConfig,
                cadence: MandazaCadence = .smooth,
                fill: CGSize = CGSize(width: 1, height: 1),
                onIdleChange: ((Bool) -> Void)? = nil) {
        self.size = size
        self.seed = seed
        self.paletteId = paletteId
        self.config = config
        self.cadence = cadence
        self.fill = fill
        self.onIdleChange = onIdleChange
    }

    public var body: some View {
        Group {
            switch cadence {
            case .smooth:
                timeline(.animation(paused: luminanceReduced || reduceMotion))
            case .interval(let seconds):
                // Honor Always-On dimming even in throttled mode.
                if luminanceReduced || reduceMotion {
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
        .onChange(of: config)    { old, new in
            if new.requiresRebuild(comparedTo: old) {
                rebuild(configOverride: new)
            } else {
                engine.config = new
            }
        }
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
            let elapsedMs = reduceMotion ? 0 : msSince(start: firstTimestamp, now: timeline.date)
            Canvas(opaque: true,
                   colorMode: .extendedLinear,
                   rendersAsynchronously: false) { ctx, canvasSize in
                drawScene(in: &ctx, size: canvasSize, timeMs: elapsedMs)
            }
            .onChange(of: timeline.date) { _, now in
                advance(now: now)
            }
        }
    }

    private func rebuild(render: CGSize? = nil, configOverride: EngineConfig? = nil) {
        let r = render ?? (builtSize == .zero ? size : builtSize)
        engine.config = configOverride ?? config
        engine.paletteId = paletteId
        let ok = engine.regenerate(width: Double(r.width),
                                   height: Double(r.height),
                                   seed: seed)
        built = ok
        firstTimestamp = nil
        wasIdle = nil
        lastAdvanceTimestamp = nil
        if ok && reduceMotion {
            engine.completeAllPaths()
        }
    }

    private func advance(now: Date) {
        guard built else { return }
        if let last = lastAdvanceTimestamp {
            let gap = now.timeIntervalSince(last)
            if gap < 0.0005 { return }
            // Absorb long stalls (Always-On dimming, wrist-down, backgrounding)
            // by sliding the start anchor forward, so elapsed time stays
            // continuous and the animation doesn't jump ahead on resume. Normal
            // per-frame gaps are well under this threshold and pass through.
            if gap > 1.0, let first = firstTimestamp {
                firstTimestamp = first.addingTimeInterval(gap)
            }
        }
        lastAdvanceTimestamp = now
        if firstTimestamp == nil { firstTimestamp = now }
        let t = msSince(start: firstTimestamp, now: now)
        let alive = engine.advance(timeMs: t)
        let idle = !alive
        if wasIdle != idle {
            wasIdle = idle
            onIdleChange?(idle)
        }
    }

    private func msSince(start: Date?, now: Date) -> Double {
        guard let start = start else { return 0 }
        return now.timeIntervalSince(start) * 1000
    }

    private func drawScene(in ctx: inout GraphicsContext, size: CGSize, timeMs: Double) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        guard built else { return }

        // Zoom about the center to crop the grid's natural margin so the
        // mandala reaches the edges (cells keep their on-screen size).
        if fill.width != 1 || fill.height != 1 {
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.scaleBy(x: fill.width, y: fill.height)
            ctx.translateBy(x: -size.width / 2, y: -size.height / 2)
        }

        let glowRadius = engine.radius / 5
        let glowScale = min(max(config.glowStrength ?? 1.0, 0.18), 1.0)
        let strokeWidth = (engine.radius / 30) * config.lineWidth

        for loop in engine.loops {
            let path = Path(engine.currentPath(for: loop))
            let color = Color(cgColor: engine.color(for: loop, timeMs: timeMs))
            var layer = ctx
            if config.glow {
                layer.addFilter(.shadow(color: color.opacity(0.55 + 0.30 * glowScale),
                                        radius: glowRadius * glowScale))
            }
            layer.stroke(path,
                         with: .color(color),
                         style: StrokeStyle(lineWidth: strokeWidth,
                                            lineCap: .round,
                                            lineJoin: .round))
        }
    }
}
