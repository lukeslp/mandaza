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
    let seed: UUID
    let paletteId: String
    let config: EngineConfig
    let cadence: MandazaCadence
    /// Overscan factor. 1.0 fits the grid with its natural margin; >1 lays the
    /// grid out larger and center-crops, so the mandala fills the viewport edge
    /// to edge (used on watchOS where every pixel counts).
    let fill: Double

    /// Fires `true` when all loops finish drawing, `false` when a new pattern
    /// starts. Parents use this to schedule auto-regenerate in Zen mode.
    var onIdleChange: ((Bool) -> Void)? = nil

    @State private var engine = MandazaEngine()
    @State private var built = false
    @State private var firstTimestamp: Date? = nil
    @State private var wasIdle: Bool? = nil
    @State private var lastAdvanceTimestamp: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    public init(size: CGSize,
                seed: UUID,
                paletteId: String,
                config: EngineConfig,
                cadence: MandazaCadence = .smooth,
                fill: Double = 1.0,
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
        .onAppear { rebuild() }
        .onChange(of: seed)      { _, _ in rebuild() }
        .onChange(of: size)      { _, _ in rebuild() }
        .onChange(of: paletteId) { _, new in engine.paletteId = new }
        .onChange(of: config)    { _, new in engine.config = new }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced && built { engine.completeAllPaths() }
        }
    }

    @ViewBuilder
    private func timeline<S: TimelineSchedule>(_ schedule: S) -> some View {
        TimelineView(schedule) { timeline in
            let elapsedMs = msSince(start: firstTimestamp, now: timeline.date)
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

    private func rebuild() {
        engine.config = config
        engine.paletteId = paletteId
        let ok = engine.regenerate(width: Double(size.width) * fill,
                                   height: Double(size.height) * fill,
                                   seed: seed.uuidString)
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

        // Overscan: the engine is laid out for `size * fill`; center it in the
        // visible canvas so the natural grid margin is cropped off the edges.
        if fill != 1.0 {
            ctx.translateBy(x: (size.width - engine.width) / 2,
                            y: (size.height - engine.height) / 2)
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
