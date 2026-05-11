/*
 File Purpose: Fullscreen tvOS ambient mandala view — remote-friendly controls,
 widget-style overlay panels, Zen clock, and App Group–backed settings.

 Primary Components:
 - `TVContentView` — canvas host, idle suppressor, panels, deep links.
 - `TVZenClockOverlay` — large clock/date overlay (Zen aesthetic).

 Inputs / Outputs:
 - Inputs: Siri Remote (Play/Pause, Menu), `mandaza://` URLs, shared settings.
 - Outputs: renders live `MandazaCanvas`, persists toggles via `MandazaSettings`.
 */

import SwiftUI
import UIKit

struct TVContentView: View {

    @State private var settings = MandazaSettings.shared
    @State private var seed = UUID().uuidString
    @State private var canvasSize: CGSize = .zero
    @State private var showPanels = true
    @State private var autoRegenTask: Task<Void, Never>? = nil
    @State private var lastIdle: Bool = false

    /// First-run defaults tuned for Apple TV ambient viewing (local UserDefaults only).
    private static let tvDefaultsAppliedKey = "MandazaTV.appliedAmbientDefaults.v1"

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    Color.black
                    MandazaCanvas(
                        size: geo.size,
                        seed: UUID(uuidString: seed) ?? UUID(),
                        paletteId: settings.paletteId,
                        config: engineConfigForTV(),
                        onIdleChange: handleIdleChange(_:)
                    )
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, new in canvasSize = new }
            }
            .ignoresSafeArea()

            if settings.zenMode && settings.zenShowClock {
                TVZenClockOverlay(
                    showSeconds: settings.zenShowSeconds,
                    showDate: settings.zenShowDate,
                    accent: BL.accent(for: settings.paletteId)
                )
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            VStack {
                if !showPanels {
                    Text("Press Menu on the Siri Remote for controls")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 48)
                        .shadow(color: .black.opacity(0.85), radius: 8)
                    Spacer()
                } else {
                    Spacer()
                    tvControlPanels
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: showPanels)
        }
        .onAppear {
            applyTVAmbientDefaultsIfNeeded()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            autoRegenTask?.cancel()
        }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .onOpenURL { handleIncomingURL($0) }
        .onPlayPauseCommand {
            regenerate()
        }
        .onExitCommand {
            showPanels.toggle()
        }
    }

    // MARK: - Panels (widget-style chrome)

    private var tvControlPanels: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                BLDot(color: BL.accent(for: settings.paletteId), size: 10)
                Text("Mandaza")
                    .font(.bl(20, weight: .semibold))
                    .foregroundStyle(BL.highlight)
                Spacer()
                Text(seedPrefix)
                    .font(.blMono(14))
                    .foregroundStyle(BL.muted)
            }

            HStack(spacing: 12) {
                Button("New Pattern") {
                    regenerate()
                }

                Toggle("Zen", isOn: $settings.zenMode)
                Toggle("Clock", isOn: $settings.zenShowClock)
                    .disabled(!settings.zenMode)
                Toggle("Glow", isOn: $settings.glow)
            }

            HStack(spacing: 12) {
                Toggle("Loop patterns", isOn: $settings.zenAutoRegen)
                    .disabled(!settings.zenMode)
                if settings.zenAutoRegen && settings.zenMode {
                    Text("Every \(Int(settings.zenAutoRegenSeconds))s")
                        .font(.bl(14))
                        .foregroundStyle(BL.muted)
                }
            }

            paletteCarousel

            Text("Play/Pause — new pattern   ·   Menu — hide/show panels")
                .font(.blMono(12))
                .foregroundStyle(BL.muted)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(BL.void.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(BL.rule, lineWidth: 1)
                )
        }
        .padding(.horizontal, 80)
        .padding(.bottom, 56)
        .focusSection()
    }

    private var paletteCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 18) {
                ForEach(Palette.all) { palette in
                    Button {
                        settings.paletteId = palette.id
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(palette.name)
                                .font(.bl(16, weight: .medium))
                                .foregroundStyle(BL.paper)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                            paletteSwatch(for: palette)
                                .frame(height: 6)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .frame(minWidth: 160, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(settings.paletteId == palette.id ? BL.deep : BL.void.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(
                                            settings.paletteId == palette.id
                                                ? BL.accent(for: palette.id)
                                                : BL.rule,
                                            lineWidth: settings.paletteId == palette.id ? 2 : 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func paletteSwatch(for palette: Palette) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(palette.stops.enumerated()), id: \.offset) { _, color in
                color
            }
        }
    }

    private var seedPrefix: String {
        String(seed.prefix(8))
    }

    // MARK: - Engine config

    /// Uses shared density/geometry; glow follows `settings.glow` (tv defaults apply on first launch).
    private func engineConfigForTV() -> EngineConfig {
        settings.engineConfig()
    }

    private func applyTVAmbientDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.tvDefaultsAppliedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.tvDefaultsAppliedKey)
        settings.zenMode = true
        settings.zenShowClock = true
        settings.zenAutoRegen = true
        settings.glow = false
    }

    // MARK: - Actions

    private func regenerate() {
        seed = UUID().uuidString
    }

    private func handleIdleChange(_ idle: Bool) {
        lastIdle = idle
        autoRegenTask?.cancel()
        guard idle, settings.zenMode, settings.zenAutoRegen, !reduceMotion else { return }
        let wait = settings.zenAutoRegenSeconds
        autoRegenTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            if !Task.isCancelled { regenerate() }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            UIApplication.shared.isIdleTimerDisabled = true
            if lastIdle, settings.zenMode, settings.zenAutoRegen, !reduceMotion {
                handleIdleChange(true)
            }
        case .background, .inactive:
            UIApplication.shared.isIdleTimerDisabled = false
            autoRegenTask?.cancel()
        @unknown default:
            break
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "mandaza" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.host == "seed", let uuidString = parts.first {
            seed = uuidString
        }
    }
}

// MARK: - Zen clock (tv-scale)

private struct TVZenClockOverlay: View {
    let showSeconds: Bool
    let showDate: Bool
    var accent: Color = BL.cyan

    var body: some View {
        TimelineView(.periodic(from: .now, by: showSeconds ? 1 : 30)) { ctx in
            let now = ctx.date
            VStack(spacing: 16) {
                Text(timeString(now))
                    .font(.system(size: 112, weight: .ultraLight, design: .default))
                    .tracking(-2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .foregroundStyle(BL.highlight)
                    .shadow(color: .black.opacity(0.75), radius: 20)
                    .shadow(color: accent.opacity(0.35), radius: 32)
                if showDate {
                    Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.bl(18, weight: .light))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(BL.paper.opacity(0.75))
                        .shadow(color: .black.opacity(0.75), radius: 8)
                }
            }
            .padding(.horizontal, 80)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clock")
    }

    private func timeString(_ date: Date) -> String {
        let style: Date.FormatStyle = showSeconds
            ? .dateTime.hour().minute().second()
            : .dateTime.hour().minute()
        return date.formatted(style)
    }
}

#Preview {
    TVContentView()
}
