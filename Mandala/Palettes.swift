import SwiftUI
import CoreGraphics

struct Palette: Identifiable, Hashable {
    let id: String
    let name: String
    /// Source hex strings — kept for inspection / debugging.
    let hexes: [String]
    /// Thread-safe CGColors. Used by the engine (which may run off main).
    let cgStops: [CGColor]
    /// SwiftUI Colors — main-thread / view-layer use.
    let stops: [Color]

    init(id: String, name: String, hexes: [String]) {
        self.id = id
        self.name = name
        self.hexes = hexes
        let rgbs = hexes.map(Palette.parseHex)
        self.cgStops = rgbs.map { CGColor(srgbRed: $0.r, green: $0.g, blue: $0.b, alpha: 1) }
        self.stops = rgbs.map { Color(red: $0.r, green: $0.g, blue: $0.b) }
    }

    static let all: [Palette] = [
        .init(id: "aurora",         name: "Aurora",         hexes: ["#3c096c", "#5a189a", "#9d4edd", "#48bfe3", "#80ffdb"]),
        .init(id: "sunset",         name: "Sunset",         hexes: ["#ff006e", "#fb5607", "#ffbe0b", "#fee440", "#fff3b0"]),
        .init(id: "ember",          name: "Ember",          hexes: ["#370617", "#9d0208", "#dc2f02", "#f48c06", "#ffba08"]),
        .init(id: "bioluminescent", name: "Bioluminescent", hexes: ["#03045e", "#0077b6", "#00b4d8", "#48cae4", "#caf0f8"]),
        .init(id: "vaporwave",      name: "Vaporwave",      hexes: ["#ff71ce", "#b967ff", "#01cdfe", "#05ffa1", "#fffb96"]),
        .init(id: "cyberpunk",      name: "Cyberpunk",      hexes: ["#ff006e", "#fb5607", "#ffbe0b", "#8338ec", "#3a86ff"]),
        .init(id: "risograph",      name: "Risograph",      hexes: ["#ff5e5b", "#ffed66", "#00cecb", "#5c5cff"]),
        .init(id: "oxblood",        name: "Oxblood",        hexes: ["#1a0a0c", "#3d0c11", "#7a1722", "#c1292e", "#f1d4af"]),
        .init(id: "arctic",         name: "Arctic",         hexes: ["#03045e", "#0077b6", "#48cae4", "#90e0ef", "#caf0f8"]),
        .init(id: "dichromat",      name: "Dichromat",      hexes: ["#0072b2", "#56b4e9", "#f0e442", "#e69f00", "#d55e00"]),
        .init(id: "amber",          name: "Amber",          hexes: ["#1f1000", "#522e0a", "#a55a17", "#dba34a", "#fdd99b"])
    ]

    static func by(id: String) -> Palette {
        // Fallback chain: requested id → legacy "riso" alias → first palette.
        all.first(where: { $0.id == id })
            ?? all.first(where: { $0.id == "risograph" && id == "riso" })
            ?? all[0]
    }

    /// Thread-safe color interpolation for the engine.
    func interpolatedCGColor(at t: Double) -> CGColor {
        let clamped = max(0, min(0.99999, t))
        guard cgStops.count > 1 else { return cgStops.first ?? CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1) }
        let seg = clamped * Double(cgStops.count - 1)
        let i = Int(seg.rounded(.down))
        let f = seg - Double(i)
        return Palette.lerp(cgStops[i], cgStops[i + 1], f)
    }

    /// View-layer color interpolation.
    func interpolated(at t: Double) -> Color {
        let clamped = max(0, min(0.99999, t))
        guard stops.count > 1 else { return stops.first ?? .white }
        let seg = clamped * Double(stops.count - 1)
        let i = Int(seg.rounded(.down))
        let f = seg - Double(i)
        return Color.lerp(stops[i], stops[i + 1], f)
    }

    private static func parseHex(_ hex: String) -> (r: Double, g: Double, b: Double) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        return (Double((v >> 16) & 0xff) / 255,
                Double((v >>  8) & 0xff) / 255,
                Double( v        & 0xff) / 255)
    }

    private static func lerp(_ a: CGColor, _ b: CGColor, _ t: Double) -> CGColor {
        let ac = a.components ?? [1, 1, 1, 1]
        let bc = b.components ?? [1, 1, 1, 1]
        let r = ac.count >= 3 ? ac[0] + (bc[0] - ac[0]) * t : 1
        let g = ac.count >= 3 ? ac[1] + (bc[1] - ac[1]) * t : 1
        let bl = ac.count >= 3 ? ac[2] + (bc[2] - ac[2]) * t : 1
        return CGColor(srgbRed: r, green: g, blue: bl, alpha: 1)
    }
}

extension Color {
    static func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ca = a.rgb()
        let cb = b.rgb()
        return Color(
            red:   ca.r + (cb.r - ca.r) * t,
            green: ca.g + (cb.g - ca.g) * t,
            blue:  ca.b + (cb.b - ca.b) * t
        )
    }

    func rgb() -> (r: Double, g: Double, b: Double) {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
        #else
        return (0, 0, 0)
        #endif
    }
}
