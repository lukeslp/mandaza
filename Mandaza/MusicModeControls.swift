import SwiftUI
import UIKit

/// A soft pulsing ring around the center button while Music Mode is
/// listening — the button's own live feedback, so no separate indicator
/// chrome is needed elsewhere on screen. Driven by `beatPulse` (a brief
/// flash on each detected beat) and `level` (ambient brightness).
struct MusicModePulseRing: View {
    var reactor: AudioReactor
    var accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reactor.source.isActive {
            let mod = reactor.source.modulation
            let effective = reduceMotion ? 0.4 : min(max(mod.level, 0), 1)
            let pulse = reduceMotion ? 0 : min(max(mod.beatPulse, 0), 1)
            Capsule()
                .strokeBorder(accent.opacity(0.35 + 0.45 * effective + 0.2 * pulse),
                              lineWidth: 1.5 + 1.5 * pulse)
                .frame(height: 50)
                .scaleEffect(1 + 0.04 * pulse)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: mod.beatPulse)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
