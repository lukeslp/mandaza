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
}
