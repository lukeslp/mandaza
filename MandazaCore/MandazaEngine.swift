import Foundation
import CoreGraphics

// MARK: - Configuration

public struct EngineConfig: Equatable, Codable, Hashable, Sendable {
    public var cellSizeRandom: Bool = true
    /// 0…1 — only used when cellSizeRandom == false. Smaller = bigger cells.
    public var cellSize: Double = 0.8
    public var randomPattern: Bool = true
    /// 0…6 — only used when randomPattern == false. Selects entry in the
    /// probability table inside the engine.
    public var geometry: Int = 6
    public var withMargin: Bool = true
    public var concentric: Bool = true
    public var centered: Bool = true
    /// 0…100 — clamps internally to [0,5] then scales above 5.
    public var regularity: Double = 5
    /// 0…1 — drawing speed coefficient.
    public var drawSpeed: Double = 0.707
    public var glow: Bool = true
    public var idlePulse: Bool = true
    public var lineWidth: Double = 1.2
    public var autoRegenIdleMs: Double = 22000

    public init() {}
}

// MARK: - Geometry constants (mirrors Cell.xs / Cell.ys / Cell.xperp / Cell.yperp)

private enum HexConst {
    static let s = sqrt(3.0)
    static let xs:    [Double] = [-0.5, 0.5, 1, 0.5, -0.5, -1]
    static let ys:    [Double] = [-s/2, -s/2, 0, s/2, s/2, 0]
    static let xperp: [Double] = [0, -s/2, -s/2, 0, s/2, s/2]
    static let yperp: [Double] = [1, 0.5, -0.5, -1, -0.5, 0.5]
    static let dxOdd: [[Int]] = [
        [-1, -1, 0, 1, 0, -1], // even row
        [-1,  0, 1, 1, 1,  0]  // odd row
    ]
    static let dxAny: [Int] = [0, 1, 1, 0, -1, -1]
}

// Probability table for points-per-edge counts. Index = geometry choice.
// Each sub-array maps "number of dots" (0..3) to relative frequency.
private let tbRelProbaNbPoints: [[Int]] = [
    [0, 1, 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1],
    [0, 1, 1, 0],
    [0, 1, 0, 1],
    [0, 0, 2, 1],
    [0, 1, 3, 1]
]

// MARK: - Reference types (mutual references => classes)

final class Dot {
    weak var cell: Cell?
    let kedge: Int
    let index: Int
    var x: Double = 0
    var y: Double = 0
    var other: Dot?
    weak var loop: Loop?
    var closed: Bool = false

    init(cell: Cell, kedge: Int, index: Int) {
        self.cell = cell
        self.kedge = kedge
        self.index = index
    }

    var point: CGPoint { CGPoint(x: x, y: y) }
}

final class Cell {
    let kx: Int
    let ky: Int
    let odd: Int
    var neighbors: [Cell?] = Array(repeating: nil, count: 6)
    var ndots: [Int] = Array(repeating: 0, count: 6)
    var dots: [[Dot]] = Array(repeating: [], count: 6)
    var flatDots: [Dot] = []
    var connectables: [[Dot]] = []
    var actives: [Dot] = []
    var xc: Double = 0
    var yc: Double = 0
    var vertices: [CGPoint] = []

    init(kx: Int, ky: Int) {
        self.kx = kx
        self.ky = ky
        self.odd = kx & 1
    }
}

final class Loop {
    var pairs: [(Dot, Dot)] = []
    var bezier: [[CGPoint]] = []     // each entry has 4 points: p0, c1, c2, p1
    var lengths: [Double] = []
    var closed: Bool = false
    var start: Dot?

    // Animation / draw state
    var path: CGMutablePath = CGMutablePath()
    var nextToDraw: Int = 0
    var pathLength: Double = 0
    var pos: Double = 0
    var prevTimeMs: Double = 0
    var colorIndex: Int = 0
    var colorTotal: Int = 1
    var randomHue: Double = 0
}

// MARK: - PRNG (Alea/Mash from JS, deterministic)

final class Mash {
    private var n: UInt32 = 0xefc8249d

    init(seed: String) {
        for ch in seed.unicodeScalars { absorb(UInt32(ch.value)) }
    }

    convenience init() {
        self.init(seed: String(format: "%.16f", Double.random(in: 0..<1)))
    }

    private func absorb(_ value: UInt32) {
        n &+= value
        var h = 0.02519603282416938 * Double(n)
        n = UInt32(truncatingIfNeeded: UInt64(h))
        h -= Double(n)
        h *= Double(n)
        n = UInt32(truncatingIfNeeded: UInt64(h))
        h -= Double(n)
        let extra = h * 4_294_967_296.0
        n &+= UInt32(truncatingIfNeeded: UInt64(extra))
    }

    /// Returns a uniform double in [0, 1).
    func next() -> Double {
        for ch in "A".unicodeScalars { absorb(UInt32(ch.value)) }
        return Double(n) * 2.3283064365386963e-10
    }

    func intAlea(_ max: Int) -> Int {
        Int(floor(next() * Double(max)))
    }

    func intAlea(_ minVal: Int, _ maxVal: Int) -> Int {
        minVal + Int(floor(next() * Double(maxVal - minVal)))
    }

    func alea(_ minVal: Double, _ maxVal: Double) -> Double {
        minVal + next() * (maxVal - minVal)
    }
}

// MARK: - Bezier helpers

private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
    CGPoint(x: t * b.x + (1 - t) * a.x, y: t * b.y + (1 - t) * a.y)
}

private func dist(_ a: CGPoint, _ b: CGPoint) -> Double {
    Double(hypot(b.x - a.x, b.y - a.y))
}

/// Splits a cubic at parameter t. Returns [left, right] each as 4 control points.
private func splitCubic(_ c: [CGPoint], _ t: Double) -> [[CGPoint]] {
    let pa = lerp(c[0], c[1], t)
    let pb = lerp(c[1], c[2], t)
    let pc = lerp(c[2], c[3], t)
    let pd = lerp(pa, pb, t)
    let pe = lerp(pb, pc, t)
    let pf = lerp(pd, pe, t)
    return [
        [c[0], pa, pd, pf],
        [pf, pe, pc, c[3]]
    ]
}

private func cubicLengthEstimate(_ c: [CGPoint]) -> Double {
    let dec0 = splitCubic(c, 0.5)
    let dec1 = splitCubic(dec0[0], 0.5)
    let dec2 = splitCubic(dec0[1], 0.5)
    return dist(dec1[0][0], dec1[0][3]) + dist(dec1[1][0], dec1[1][3])
         + dist(dec2[0][0], dec2[0][3]) + dist(dec2[1][0], dec2[1][3])
}

// MARK: - Engine

/// Single in-flight mandala. Owns grid, loops, animation state.
final class MandazaEngine {

    // Inputs
    var config: EngineConfig
    var paletteId: String

    // Sizing / grid
    private(set) var width: Double = 0
    private(set) var height: Double = 0
    private(set) var radius: Double = 0
    private var nbx: Int = 0
    private var nby: Int = 0
    private var offsx: Double = 0
    private var offsy: Double = 0
    private var grid: [[Cell]] = []

    // Loops / state
    private(set) var loops: [Loop] = []
    private(set) var allDrawn: Bool = false

    // RNGs
    private var rndStruct = Mash()
    private var rndCol = Mash()
    private var rndGen = Mash()

    // Resolved per-run
    private var concentric: Bool = true
    private var uncentered: Bool = false
    private var internRegularity: Double = 5
    private var withMargin: Bool = true
    private var geometryChoice: Int = 6

    // Limits
    private static let MIN_NB_CELLS = 10.0
    private static let MAX_NB_CELLS = 100.0

    init(config: EngineConfig = EngineConfig(), paletteId: String = "aurora") {
        self.config = config
        self.paletteId = paletteId
    }

    /// Recompute grid + loops for the given canvas size.
    /// `seed` lets you regenerate the same composition (e.g. for high-res export).
    @discardableResult
    func regenerate(width: Double, height: Double, seed: String? = nil) -> Bool {
        self.width = width
        self.height = height
        self.withMargin = config.withMargin
        self.concentric = config.concentric
        self.uncentered = !config.centered
        self.internRegularity = config.regularity <= 5
            ? config.regularity
            : 5 + (95.0 / 5.0) * (config.regularity - 5)

        let baseSeed = seed ?? UUID().uuidString
        rndStruct = Mash(seed: baseSeed + "/struct")
        rndCol    = Mash(seed: baseSeed + "/col")
        rndGen    = Mash(seed: baseSeed + "/gen")

        guard buildGrid() else { return false }
        loops = buildLoops()
        for (i, loop) in loops.enumerated() {
            loop.path = CGMutablePath()
            loop.path.move(to: loop.bezier[0][0])
            loop.colorIndex = i
            loop.colorTotal = loops.count
            loop.randomHue = Double(rndCol.intAlea(360))
            loop.nextToDraw = 0
            loop.pathLength = 0
            loop.pos = 0
            loop.prevTimeMs = 0
        }
        allDrawn = false
        return true
    }

    /// Build an entirely-drawn snapshot for export — same grid + palette as the
    /// current animated state (use `regenerate(seed:)` first if you need stability).
    func completeAllPaths() {
        for loop in loops {
            loop.path = CGMutablePath()
            guard !loop.bezier.isEmpty else { continue }
            loop.path.move(to: loop.bezier[0][0])
            for cubic in loop.bezier {
                loop.path.addCurve(to: cubic[3], control1: cubic[1], control2: cubic[2])
            }
            loop.nextToDraw = loop.bezier.count
            loop.pos = loop.lengths.reduce(0, +)
            loop.pathLength = loop.pos
        }
        allDrawn = true
    }

    /// Advance animation. Returns false when no further drawing is happening
    /// (everything has been stroked completely).
    @discardableResult
    func advance(timeMs: Double) -> Bool {
        var anyAlive = false
        let drawSpeed = (10 + 1990 * config.drawSpeed * config.drawSpeed) / 1000.0
        for loop in loops {
            if loop.prevTimeMs == 0 { loop.prevTimeMs = timeMs }
            let dt = timeMs - loop.prevTimeMs
            loop.prevTimeMs = timeMs
            if loop.nextToDraw < loop.bezier.count {
                loop.pos += dt * drawSpeed
                while loop.nextToDraw < loop.bezier.count
                   && loop.pos >= loop.pathLength + loop.lengths[loop.nextToDraw] {
                    let idx = loop.nextToDraw
                    loop.path.addCurve(to: loop.bezier[idx][3],
                                       control1: loop.bezier[idx][1],
                                       control2: loop.bezier[idx][2])
                    loop.pathLength += loop.lengths[idx]
                    loop.nextToDraw += 1
                }
                anyAlive = true
            }
        }
        if !anyAlive { allDrawn = true }
        return anyAlive
    }

    /// Path to stroke for `loop` at the current animation pos — includes a
    /// partial fragment of the in-flight curve. Caller chooses color / shadow.
    func currentPath(for loop: Loop) -> CGPath {
        let p = CGMutablePath()
        p.addPath(loop.path)
        if loop.nextToDraw < loop.bezier.count {
            let alpha = (loop.pos - loop.pathLength) / loop.lengths[loop.nextToDraw]
            let frag = splitCubic(loop.bezier[loop.nextToDraw], max(0, min(1, alpha)))[0]
            p.addCurve(to: frag[3], control1: frag[1], control2: frag[2])
        }
        return p
    }

    /// Color to stroke `loop` with, given current time (pulse offset).
    /// Thread-safe — does not touch SwiftUI.
    func color(for loop: Loop, timeMs: Double) -> CGColor {
        let palette = Palette.by(id: paletteId)
        let total = max(1, loop.colorTotal)
        var t = total > 1 ? Double(loop.colorIndex) / Double(total - 1) : 0.5
        let pulse = config.idlePulse ? timeMs : 0
        t += 0.18 * sin(pulse / 2500 + Double(loop.colorIndex) * 0.6)
        if t < 0 { t = -t }
        if t > 1 { t = 2 - t }
        return palette.interpolatedCGColor(at: max(0, min(1, t)))
    }

    // MARK: - Grid construction (port of createGrid)

    private func buildGrid() -> Bool {
        let s = HexConst.s
        let nbCellsTarget: Double = config.cellSizeRandom
            ? rndGen.alea(Self.MIN_NB_CELLS, Self.MAX_NB_CELLS)
            : sqrt(config.cellSize) * Self.MIN_NB_CELLS
              + (1 - sqrt(config.cellSize)) * Self.MAX_NB_CELLS

        var r = sqrt(((width * height) / nbCellsTarget) * 2 / 3 / s)
        var ok = false
        for _ in 0..<100 {
            if withMargin {
                nbx = Int(floor(((width - 20) / r + 0.5) / 1.5))
                nby = Int(floor((height - 20) / r / s - 0.5)) + 1
            } else {
                nbx = Int(ceil((width / r - 0.5) / 1.5)) + 1
                nby = Int(ceil(height / r / s + 0.5))
            }
            if nbx > 1 && nby > 1 { ok = true; break }
            r *= 0.95
        }
        guard ok else { return false }
        radius = r

        offsx = (width - r * (0.5 + 1.5 * Double(nbx))) / 2 + r
        offsy = (height - r * s * (0.5 + Double(nby))) / 2 + (r * s) / 2

        // Build cells
        grid = (0..<nby).map { ky in
            (0..<nbx).map { kx in Cell(kx: kx, ky: ky) }
        }
        for line in grid {
            for cell in line { setNeighbors(cell) }
        }

        // Geometry pattern: weighted urn of dot counts
        geometryChoice = config.randomPattern
            ? rndGen.intAlea(tbRelProbaNbPoints.count)
            : min(max(0, config.geometry), tbRelProbaNbPoints.count - 1)
        var tbNbPoints: [Int] = []
        for (nb, freq) in tbRelProbaNbPoints[geometryChoice].enumerated() {
            for _ in 0..<freq { tbNbPoints.append(nb) }
        }

        // Assign dot counts to each shared edge
        for line in grid {
            for cell in line {
                for dir in 0..<6 {
                    if cell.ndots[dir] != 0 { continue }
                    guard let other = cell.neighbors[dir] else { continue }
                    let otherDir = (dir + 3) % 6
                    let pick = tbNbPoints[rndStruct.intAlea(tbNbPoints.count)]
                    cell.ndots[dir] = pick
                    other.ndots[otherDir] = pick
                }
            }
        }

        // Find cells with odd total dot counts — they need one dot "closed"
        var odds: [Cell] = []
        for line in grid {
            for cell in line {
                let total = cell.ndots.reduce(0, +)
                if total & 1 == 1 { odds.append(cell) }
            }
        }

        // Allocate dot pairs
        for line in grid {
            for cell in line {
                for dir in 0..<6 {
                    let n = cell.ndots[dir]
                    if n == 0 { continue }
                    guard let other = cell.neighbors[dir] else { continue }
                    let otherDir = (dir + 3) % 6
                    if !cell.dots[dir].isEmpty { continue }
                    var here: [Dot] = []
                    var there: [Dot] = []
                    for kdot in 0..<n {
                        let a = Dot(cell: cell, kedge: dir, index: kdot)
                        let b = Dot(cell: other, kedge: otherDir, index: n - 1 - kdot)
                        a.other = b
                        b.other = a
                        here.append(a)
                        there.insert(b, at: 0) // build there in mirrored order: index n-1-kdot at position n-1-kdot
                    }
                    // The JS stores them at index n-1-kdot in `other.dots[otherDir]`.
                    // We rebuild explicitly to match indexing exactly:
                    var thereOrdered = Array<Dot?>(repeating: nil, count: n)
                    for (k, dot) in here.enumerated() {
                        let mirror = dot.other!
                        thereOrdered[n - 1 - k] = mirror
                    }
                    cell.dots[dir] = here
                    other.dots[otherDir] = thereOrdered.compactMap { $0 }
                }
            }
        }

        for line in grid { for cell in line { flattenDots(cell) } }

        if !odds.isEmpty {
            if !closeOne(in: odds, idx: 0) {
                // Theoretically unreachable with valid input
                return false
            }
        }

        for line in grid { for cell in line { sizeCell(cell) } }
        for line in grid { for cell in line { makeConnectables(cell) } }
        return true
    }

    private func setNeighbors(_ cell: Cell) {
        let oddRow = cell.odd
        for dir in 0..<6 {
            let kx = cell.kx + HexConst.dxAny[dir]
            let ky = cell.ky + HexConst.dxOdd[oddRow][dir]
            if ky >= 0 && ky < grid.count && kx >= 0 && kx < grid[ky].count {
                cell.neighbors[dir] = grid[ky][kx]
            } else {
                cell.neighbors[dir] = nil
            }
        }
    }

    private func flattenDots(_ cell: Cell) {
        cell.flatDots = cell.dots.flatMap { $0 }
    }

    private func makeConnectables(_ cell: Cell) {
        var alive: [Dot] = []
        for d in cell.flatDots where !d.closed { alive.append(d) }
        cell.connectables = [alive]
        cell.actives = alive
    }

    private func sizeCell(_ cell: Cell) {
        let r = radius
        cell.xc = offsx + Double(cell.kx) * 1.5 * r
        cell.yc = offsy + Double(cell.ky) * r * HexConst.s + 0.5 * Double(cell.odd) * r * HexConst.s
        cell.vertices = (0..<6).map { k in
            CGPoint(x: cell.xc + HexConst.xs[k] * r, y: cell.yc + HexConst.ys[k] * r)
        }
        for kedge in 0..<6 {
            let n = cell.ndots[kedge]
            if n == 0 { continue }
            let p0 = cell.vertices[kedge]
            let p1 = cell.vertices[(kedge + 1) % 6]
            let mat: [Double]
            switch n {
            case 1: mat = [1.0/2.0]
            case 2: mat = [3.0/8.0, 5.0/8.0]
            default: mat = [9.0/32.0, 1.0/2.0, 23.0/32.0]
            }
            for kdot in 0..<n {
                let p = lerp(p0, p1, mat[kdot])
                cell.dots[kedge][kdot].x = Double(p.x)
                cell.dots[kedge][kdot].y = Double(p.y)
            }
        }
    }

    /// Recursive backtracker — close exactly one dot per odd cell so total
    /// connectable count becomes even everywhere.
    private func closeOne(in odds: [Cell], idx: Int) -> Bool {
        let cell = odds[idx]
        var order = cell.flatDots
        while !order.isEmpty {
            let i = rndStruct.intAlea(order.count)
            let dot = order.remove(at: i)
            if dot.other == nil || dot.other?.closed != true {
                dot.closed = true
                if idx == odds.count - 1 { return true }
                if closeOne(in: odds, idx: idx + 1) { return true }
                dot.closed = false
            }
        }
        return false
    }

    // MARK: - Loop construction (port of createLoops)

    private func buildLoops() -> [Loop] {
        var loops: [Loop] = []

        // Pick starting cell
        var cell: Cell
        if uncentered {
            cell = grid[rndStruct.intAlea(nby)][rndStruct.intAlea(nbx)]
        } else {
            cell = grid[(nby - 1) / 2][(nbx - 1) / 2]
        }
        // Walk to a non-empty cell
        var spins = 0
        while cell.connectables.first?.isEmpty ?? true {
            cell = grid[rndStruct.intAlea(nby)][rndStruct.intAlea(nbx)]
            spins += 1
            if spins > 2000 { return [] }
        }

        let firstLoop = Loop()
        let startList = cell.connectables[0]
        buildLoop(firstLoop, start: startList[startList.count / 2])
        loops.append(firstLoop)
        loopToBezier(firstLoop)

        var k = 0
        while k < loops.count {
            let sl = loops[k]
            var foundDot: Dot? = nil
            for pair in sl.pairs {
                let d0 = pair.0
                let d1 = pair.1
                if let nx = nextCW(d0.cell, d0) { foundDot = nx; break }
                if let nx = nextCCW(d1.cell, d1) { foundDot = nx; break }
                if let nx = nextCCW(d0.cell, d0) { foundDot = nx; break }
                if let nx = nextCW(d1.cell, d1) { foundDot = nx; break }
            }
            if let d = foundDot {
                let lp = Loop()
                buildLoop(lp, start: d)
                loops.append(lp)
                loopToBezier(lp)
            } else {
                k += 1
            }
        }

        // Sweep stragglers
        for line in grid {
            for cell in line {
                for dot in cell.actives where dot.loop == nil {
                    let lp = Loop()
                    buildLoop(lp, start: dot)
                    loops.append(lp)
                    loopToBezier(lp)
                }
            }
        }

        return loops
    }

    private func buildLoop(_ loop: Loop, start: Dot) {
        loop.start = start
        // Forward extension
        while extendLoop(loop, direct: true) {
            if loop.pairs[0].0.other === loop.pairs[loop.pairs.count - 1].1 {
                loop.closed = true
                break
            }
        }
        // Backward extension if not closed
        if !loop.closed {
            repeat { } while extendLoop(loop, direct: false)
        }
        for (a, b) in loop.pairs {
            a.loop = loop
            b.loop = loop
        }
    }

    private func extendLoop(_ loop: Loop, direct: Bool) -> Bool {
        var dot0: Dot
        if loop.pairs.isEmpty {
            dot0 = loop.start!
        } else if direct {
            guard let other = loop.pairs.last!.1.other else { return false }
            dot0 = other
        } else {
            guard let other = loop.pairs[0].0.other else { return false }
            dot0 = other
        }
        if dot0.closed { return false }
        guard let cell = dot0.cell, let dot1 = pickNextDot(cell, dot0, direct: direct) else { return false }
        if direct {
            loop.pairs.append((dot0, dot1))
        } else {
            loop.pairs.insert((dot1, dot0), at: 0)
        }
        return true
    }

    private func pickNextDot(_ cell: Cell, _ dotIn: Dot, direct: Bool) -> Dot? {
        for kcon in 0..<cell.connectables.count {
            guard let k0 = cell.connectables[kcon].firstIndex(where: { $0 === dotIn }) else { continue }
            var k1: Int
            let count = cell.connectables[kcon].count
            if concentric && rndStruct.intAlea(Int(internRegularity)) != 0 {
                if direct { k1 = (k0 + 1) % count }
                else { k1 = (k0 + count - 1) % count }
            } else {
                k1 = rndStruct.intAlea(count / 2) * 2 + ((k0 & 1) ^ 1)
            }
            let dotOut = cell.connectables[kcon][k1]
            var lo = k0, hi = k1
            if lo > hi { swap(&lo, &hi) }
            // Splice indices [lo … hi]
            let extracted = Array(cell.connectables[kcon][lo...hi])
            cell.connectables[kcon].removeSubrange(lo...hi)
            // narr = extracted with first and last removed
            var narr = extracted
            if !narr.isEmpty { narr.removeFirst() }
            if !narr.isEmpty { narr.removeLast() }
            if !narr.isEmpty { cell.connectables.append(narr) }
            if cell.connectables[kcon].isEmpty {
                cell.connectables.remove(at: kcon)
            }
            return dotOut
        }
        return nil
    }

    private func nextCW(_ cell: Cell?, _ dot: Dot) -> Dot? {
        guard let cell = cell else { return nil }
        guard let k = cell.actives.firstIndex(where: { $0 === dot }) else { return nil }
        let n = cell.actives[(k + 1) % cell.actives.count]
        return n.loop == nil ? n : nil
    }

    private func nextCCW(_ cell: Cell?, _ dot: Dot) -> Dot? {
        guard let cell = cell else { return nil }
        guard let k = cell.actives.firstIndex(where: { $0 === dot }) else { return nil }
        let n = cell.actives[(k + cell.actives.count - 1) % cell.actives.count]
        return n.loop == nil ? n : nil
    }

    /// Bezier curve construction inside one cell from p0 to p1.
    /// (port of Cell.toBezier)
    private func cellToBezier(_ cell: Cell, _ p0: Dot, _ p1: Dot) -> [CGPoint] {
        let bin = p0.kedge
        let bout = p1.kedge
        let diff = abs(bout - bin)
        let r = radius
        let p0pt = p0.point
        let p1pt = p1.point
        var pa = CGPoint.zero, pb = CGPoint.zero

        switch diff {
        case 0:
            let dd = 0.2 * r
            pa = CGPoint(x: p0pt.x + HexConst.xperp[bin] * dd, y: p0pt.y + HexConst.yperp[bin] * dd)
            pb = CGPoint(x: p1pt.x + HexConst.xperp[bout] * dd, y: p1pt.y + HexConst.yperp[bout] * dd)
        case 1, 5:
            let kCommVert: Int = ((bout - bin == -1) || (bout - bin == 5)) ? bin : bout
            let din = dist(cell.vertices[kCommVert], p0pt)
            let dout = dist(cell.vertices[kCommVert], p1pt)
            let dd = 0.75
            pa = CGPoint(x: p0pt.x + HexConst.xperp[bin] * dd * dout, y: p0pt.y + HexConst.yperp[bin] * dd * dout)
            pb = CGPoint(x: p1pt.x + HexConst.xperp[bout] * dd * din, y: p1pt.y + HexConst.yperp[bout] * dd * din)
        case 2, 4:
            let dd = 0.6 * r
            pa = CGPoint(x: p0pt.x + HexConst.xperp[bin] * dd, y: p0pt.y + HexConst.yperp[bin] * dd)
            pb = CGPoint(x: p1pt.x + HexConst.xperp[bout] * dd, y: p1pt.y + HexConst.yperp[bout] * dd)
        case 3:
            let dd = 0.5 * r
            pa = CGPoint(x: p0pt.x + HexConst.xperp[bin] * dd, y: p0pt.y + HexConst.yperp[bin] * dd)
            pb = CGPoint(x: p1pt.x + HexConst.xperp[bout] * dd, y: p1pt.y + HexConst.yperp[bout] * dd)
        default:
            // unreachable for valid edge indices
            break
        }
        return [p0pt, pa, pb, p1pt]
    }

    private func loopToBezier(_ loop: Loop) {
        loop.bezier = loop.pairs.map { pair in
            cellToBezier(pair.0.cell!, pair.0, pair.1)
        }
        loop.lengths = loop.bezier.map { cubicLengthEstimate($0) }
    }
}

// MARK: - Off-main rendering

import UIKit

extension MandazaEngine {

    /// Renders a finished mandala straight to a CGContext, bypassing SwiftUI. Safe
    /// to call from any thread — `UIGraphicsImageRenderer` is documented thread-safe
    /// and the engine has no UIKit/SwiftUI dependencies.
    ///
    /// Used by the export pipeline so a 4K save doesn't hang the main thread.
    static func renderImage(seed: String,
                            paletteId: String,
                            config: EngineConfig,
                            size: CGSize) -> UIImage? {
        guard size.width > 1, size.height > 1 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1   // caller passes the target pixel size already
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))

            let engine = MandazaEngine(config: config, paletteId: paletteId)
            guard engine.regenerate(width: Double(size.width),
                                    height: Double(size.height),
                                    seed: seed) else { return }
            engine.completeAllPaths()

            let glowRadius = engine.radius / 5
            let strokeWidth = (engine.radius / 30) * config.lineWidth

            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setLineWidth(strokeWidth)

            for loop in engine.loops {
                let path = engine.currentPath(for: loop)
                let color = engine.color(for: loop, timeMs: 0)
                ctx.setStrokeColor(color)
                if config.glow {
                    ctx.setShadow(offset: .zero, blur: glowRadius, color: color)
                } else {
                    ctx.setShadow(offset: .zero, blur: 0, color: nil)
                }
                ctx.addPath(path)
                ctx.strokePath()
            }
        }
    }
}
