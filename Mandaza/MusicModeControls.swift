import SwiftUI
import UIKit

/// Attaches Music Mode as a long-press on an existing button (the dock's
/// center "New" control) instead of a dedicated dock icon — the toggle rides
/// the app's one prominent action rather than adding chrome. The first-ever
/// activation shows a priming explanation BEFORE the system microphone
/// prompt so the OS dialog never appears cold; a denied permission routes to
/// Settings instead of failing silently.
///
/// Long-press is disabled whenever VoiceOver or Switch Control is active
/// (`enabled: false`) — same rule the canvas's long-press-to-regenerate
/// already follows. Assistive-tech users get Music Mode via the ordinary
/// Toggle in Settings instead, which VoiceOver announces natively.
struct MusicModeLongPress: ViewModifier {
    var reactor: AudioReactor
    @Binding var hasPrimed: Bool
    var enabled: Bool
    /// Lets the host reset its controls-fade timer on any interaction here
    /// (including alert dismissals), so the dock never fades mid-dialog.
    var onInteract: () -> Void = {}

    @State private var showPrimer = false
    @State private var showDenied = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                enabled
                    ? LongPressGesture(minimumDuration: 0.5).onEnded { _ in triggered() }
                    : nil
            )
            .alert("Music Mode", isPresented: $showPrimer) {
                Button("Continue") {
                    onInteract()
                    hasPrimed = true
                    Task { await reactor.start() }
                }
                Button("Cancel", role: .cancel) { onInteract() }
            } message: {
                Text("Mandaza listens through the microphone to make the mandala move with your music. Audio is never recorded or stored.")
            }
            .alert("Microphone Access Needed", isPresented: $showDenied) {
                Button("Open Settings") {
                    onInteract()
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { onInteract() }
            } message: {
                Text("Mandaza needs microphone access to make the mandala move with your music. Audio is never recorded or stored.")
            }
    }

    private func triggered() {
        onInteract()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if reactor.source.isActive {
            reactor.stop()
        } else if reactor.state == .denied {
            showDenied = true
        } else if !hasPrimed {
            showPrimer = true
        } else {
            Task { await reactor.start() }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

extension View {
    /// Long-press = toggle Music Mode. See `MusicModeLongPress`.
    func musicModeLongPress(reactor: AudioReactor,
                             hasPrimed: Binding<Bool>,
                             enabled: Bool,
                             onInteract: @escaping () -> Void = {}) -> some View {
        modifier(MusicModeLongPress(reactor: reactor,
                                    hasPrimed: hasPrimed,
                                    enabled: enabled,
                                    onInteract: onInteract))
    }
}

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
