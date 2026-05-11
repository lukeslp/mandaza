import SwiftUI

/// SwiftUI Canvas + TimelineView host for the live, animated mandaza.
/// Owns one engine instance and an animation clock. Re-creates the engine
/// when its size or seed changes.
struct MandazaCanvas: View {
    let size: CGSize
    let seed: UUID
    let paletteId: String
    let config: EngineConfig

    /// Fires `true` when all loops finish drawing, `false` when a new pattern
    /// starts. Parents use this to schedule auto-regenerate in Zen mode.
    var onIdleChange: ((Bool) -> Void)? = nil

    @State private var engine = MandazaEngine()
    @State private var built = false
    @State private var firstTimestamp: Date? = nil
    @State private var wasIdle: Bool? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced

    var body: some View {
        TimelineView(.animation(paused: luminanceReduced)) { timeline in
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
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear { rebuild() }
        .onChange(of: seed)      { _, _ in rebuild() }
        .onChange(of: size)      { _, _ in rebuild() }
        .onChange(of: paletteId) { _, new in engine.paletteId = new }
        .onChange(of: config)    { _, new in engine.config = new }
    }

    private func rebuild() {
        engine.config = config
        engine.paletteId = paletteId
        let ok = engine.regenerate(width: Double(size.width),
                                   height: Double(size.height),
                                   seed: seed.uuidString)
        built = ok
        firstTimestamp = nil
        wasIdle = nil
        if ok && reduceMotion {
            engine.completeAllPaths()
        }
    }

    private func advance(now: Date) {
        guard built else { return }
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

        let glowRadius = engine.radius / 5
        let strokeWidth = (engine.radius / 30) * config.lineWidth

        for loop in engine.loops {
            let path = Path(engine.currentPath(for: loop))
            let color = Color(cgColor: engine.color(for: loop, timeMs: timeMs))
            var layer = ctx
            if config.glow {
                layer.addFilter(.shadow(color: color.opacity(0.85),
                                        radius: glowRadius))
            }
            layer.stroke(path,
                         with: .color(color),
                         style: StrokeStyle(lineWidth: strokeWidth,
                                            lineCap: .round,
                                            lineJoin: .round))
        }
    }
}
