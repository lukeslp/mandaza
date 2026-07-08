import SwiftUI
import UIKit

/// Dock control that toggles Music Mode. The first-ever activation shows a
/// priming explanation BEFORE the system microphone prompt so the OS dialog
/// never appears cold; a denied mic permission routes to Settings instead of
/// failing silently. Self-contained — ContentView only places the view and
/// hands it the reactor plus the persisted `hasPrimed` flag.
struct MusicModeButton: View {
    var reactor: AudioReactor
    @Binding var hasPrimed: Bool
    var accent: Color = BL.cyan
    /// Lets the host reset its controls-fade timer on any interaction here
    /// (including alert dismissals), so the dock never fades mid-dialog.
    var onInteract: () -> Void = {}

    @State private var showPrimer = false
    @State private var showDenied = false

    private var isActive: Bool { reactor.source.isActive }

    var body: some View {
        Button {
            tapped()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? accent : BL.highlight)
                    .frame(height: 26)
                    .shadow(color: isActive ? accent.opacity(0.55) : .clear, radius: 8)

                Text("Music")
                    .font(.blMono(10, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? accent.opacity(0.85) : BL.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Music Mode")
        .accessibilityValue(isActive ? "On" : "Off")
        .accessibilityHint(isActive
            ? "Stops listening to the microphone."
            : "Makes the mandala move with sound from the microphone.")
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

    private func tapped() {
        onInteract()
        UISelectionFeedbackGenerator().selectionChanged()
        if isActive {
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

/// Three-bar level meter shown while Music Mode is listening. Heights follow
/// the reactor's smoothed bass/mid/treble; monochrome white so it never
/// competes with the palette. Renders nothing when the reactor is idle, so
/// ContentView can place it unconditionally.
struct MusicModeIndicator: View {
    var reactor: AudioReactor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barWidth: CGFloat = 3
    private let minHeight: CGFloat = 4
    private let maxRise: CGFloat = 14

    var body: some View {
        if reactor.source.isActive {
            HStack(alignment: .bottom, spacing: 3) {
                bar(level: reactor.source.modulation.bass)
                bar(level: reactor.source.modulation.mid)
                bar(level: reactor.source.modulation.treble)
            }
            .frame(height: minHeight + maxRise, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Music Mode active, listening")
        }
    }

    private func bar(level: Double) -> some View {
        // With Reduce Motion the bars hold a steady mid height — still reads
        // as "listening" without dancing.
        let effective = reduceMotion ? 0.5 : min(max(level, 0), 1)
        return Capsule()
            .fill(Color.white.opacity(0.7))
            .frame(width: barWidth, height: minHeight + maxRise * CGFloat(effective))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: effective)
    }
}
