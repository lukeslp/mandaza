/*
 File Purpose: Shared mapping from the persisted zen clock “weight” slider (0…1)
 to SwiftUI `Font.Weight` and human-readable labels.

 Primary Components:
 - `ZenClockTypography` — `fontWeight(for:)` and `weightLabel(for:)`.

 Inputs / Outputs:
 - Inputs: slider value `Double` (typically 0.1…0.75 in UI).
 - Outputs: `Font.Weight` for rendering; `String` for settings readouts.
 */

import SwiftUI

/// One source of truth so iOS, tvOS, and tests never drift label vs. glyph weight.
public enum ZenClockTypography {

    public static func fontWeight(for value: Double) -> Font.Weight {
        switch value {
        case ..<0.15: return .ultraLight
        case ..<0.25: return .thin
        case ..<0.35: return .light
        case ..<0.5: return .regular
        case ..<0.62: return .medium
        case ..<0.78: return .semibold
        default: return .bold
        }
    }

    public static func weightLabel(for value: Double) -> String {
        switch value {
        case ..<0.15: return "Ultra Light"
        case ..<0.25: return "Thin"
        case ..<0.35: return "Light"
        case ..<0.5: return "Regular"
        case ..<0.62: return "Medium"
        case ..<0.78: return "Semi Bold"
        default: return "Bold"
        }
    }

    // MARK: - Layout & style maps
    //
    // Pure maps so iOS, tvOS, watchOS, and tests all resolve position and
    // font style identically. The overlay pairs `alignment(for:)` with a
    // safe-area-aware padding, so these only decide the anchor corner/edge.

    /// Where the clock block anchors inside the full-screen overlay frame.
    public static func alignment(for position: ZenClockPosition) -> Alignment {
        switch position {
        case .top, .upperThird: return .top
        case .center:           return .center
        case .lowerThird:       return .bottom
        case .topLeading:       return .topLeading
        case .topTrailing:      return .topTrailing
        case .bottomLeading:    return .bottomLeading
        case .bottomTrailing:   return .bottomTrailing
        }
    }

    /// Font design for a style. `condensed` is not a design — it returns `nil`
    /// and is expressed through `fontWidth(for:)` instead.
    public static func fontDesign(for style: ZenClockFontStyle) -> Font.Design? {
        switch style {
        case .system:     return .default
        case .rounded:    return .rounded
        case .monospaced: return .monospaced
        case .serif:      return .serif
        case .condensed:  return nil
        }
    }

    /// Font width for a style. Only `condensed` narrows the glyphs; everything
    /// else keeps the standard width.
    public static func fontWidth(for style: ZenClockFontStyle) -> Font.Width {
        style == .condensed ? .condensed : .standard
    }

    /// A resolved `Font` for a clock at `size`, honoring style (design + width)
    /// and the persisted weight slider.
    public static func clockFont(size: CGFloat,
                                 style: ZenClockFontStyle,
                                 weight: Double) -> Font {
        let base = Font.system(size: size,
                               weight: fontWeight(for: weight),
                               design: fontDesign(for: style) ?? .default)
        return base.width(fontWidth(for: style))
    }
}
