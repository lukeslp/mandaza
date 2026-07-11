import SwiftUI

/// Bioluminescent design system.
///
/// Deep-ocean black, neon dot palette per phylum. Inter-feeling system fonts,
/// low-opacity overlays, glow shadows. Translated from the data-poems /
/// bioluminescence aesthetic into native SwiftUI tokens.
public enum BL {

    // MARK: - Ground tones

    /// Deep-ocean black with a faint blue undertone. The true backdrop.
    public static let void      = Color(hex: "#010408")
    /// One step up from void — used for floating chrome backgrounds.
    public static let deep      = Color(hex: "#060a10")
    /// Default text color. Soft, never pure white.
    public static let paper     = Color(hex: "#c0c8d0")
    /// Emphasis text — display titles, active values.
    public static let highlight = Color(hex: "#e0e6ed")
    /// Secondary / supporting text.
    public static let muted     = Color(red: 160/255, green: 176/255, blue: 192/255).opacity(0.78)
    /// Hairline rule color (1px borders).
    public static let rule      = Color.white.opacity(0.08)

    /// Warm parchment ground for the light canvas theme.
    public static let parchment = Color(hex: "#efe8dc")
    /// Soft ink for paper-theme stroke shadows.
    public static let ink       = Color(hex: "#1c1812")

    /// Fill color for the live mandala canvas.
    public static func canvasGround(for theme: CanvasTheme) -> Color {
        switch theme {
        case .void:  return .black
        case .paper: return parchment
        }
    }

    // MARK: - Phylum palette

    public static let cyan   = Color(hex: "#00ffff")
    public static let blue   = Color(hex: "#4488ff")
    public static let green  = Color(hex: "#00ff88")
    public static let violet = Color(hex: "#cc44ff")
    public static let amber  = Color(hex: "#ffdd00")
    public static let pink   = Color(hex: "#ff6688")
    public static let orange = Color(hex: "#ff8844")

    /// Map a palette id → its phylum accent color (drives chrome highlights).
    public static func accent(for paletteId: String) -> Color {
        switch paletteId {
        case "aurora":         return violet
        case "sunset":         return pink
        case "ember":          return orange
        case "bioluminescent": return cyan
        case "vaporwave":      return violet
        case "cyberpunk":      return blue
        case "risograph":      return pink
        case "oxblood":        return orange
        case "canopy":         return green
        case "arctic":         return green   // legacy alias
        case "dichromat":      return amber
        case "amber":          return amber
        case "terrain":        return orange
        default:               return green
        }
    }
}

// MARK: - Typography helpers

public extension Font {
    /// Body-ish, Inter-feeling. System default design is closest to Inter in
    /// SF; rounded is too soft, monospaced is too rigid.
    static func bl(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Mono caption — JetBrains Mono stand-in.
    static func blMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Components

/// Tiny phylum dot — the bioluminescent organism marker. Glows when
/// `bright` is true; sits quietly at low opacity otherwise.
public struct BLDot: View {
    let color: Color
    var size: CGFloat = 8
    var bright: Bool = true

    public init(color: Color, size: CGFloat = 8, bright: Bool = true) {
        self.color = color
        self.size = size
        self.bright = bright
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(bright ? 0.8 : 0),
                    radius: bright ? size * 1.5 : 0)
            .opacity(bright ? 1.0 : 0.5)
    }
}

/// Mono uppercase caption — section labels, meta text.
public struct BLCaption: View {
    let text: String
    var tint: Color = BL.muted

    public init(_ text: String, tint: Color = BL.muted) {
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        Text(text)
            .font(.blMono(11))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(tint)
    }
}

private extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xff) / 255
        let g = Double((v >>  8) & 0xff) / 255
        let b = Double( v        & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}
