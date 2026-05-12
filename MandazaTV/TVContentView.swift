/*
 File Purpose: Fullscreen tvOS ambient mandala view — remote-friendly controls,
 widget-style overlay panels, Zen clock, and App Group–backed settings.

 Primary Components:
 - `TVContentView` — canvas host, idle suppressor, dock, Zen sheet, deep links.
 - `TVZenClockOverlay` — large clock/date overlay (Zen aesthetic).
 - `TVZenOptionsSheet` — Zen / loop / interval tuning for 10-foot UI.

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

    /// Menu toggles dock visibility (explicit chrome vs ambient-only).
    @State private var showDock = true
    @State private var showZenSheet = false

    @State private var autoRegenTask: Task<Void, Never>? = nil
    @State private var lastIdle: Bool = false

    @FocusState private var dockFocus: TVDockFocus?

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
            .accessibilitySortPriority(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mandala canvas")
            .accessibilityHint("Shows animated patterns. Press Play Pause on the Siri Remote for a new pattern. Press Menu to show or hide controls.")

            if settings.zenMode && settings.zenShowClock {
                TVZenClockOverlay(
                    showSeconds: settings.zenShowSeconds,
                    showDate: settings.zenShowDate,
                    accent: BL.accent(for: settings.paletteId)
                )
                .allowsHitTesting(false)
                .accessibilitySortPriority(2)
                .transition(ambientTransition())
            }

            VStack(spacing: 0) {
                if !showDock {
                    ambientHintChrome
                        .accessibilitySortPriority(4)
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    tvControlDock
                        .accessibilitySortPriority(3)
                        .transition(dockTransition())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: showDock)
        }
        .onAppear {
            applyTVAmbientDefaultsIfNeeded()
            UIApplication.shared.isIdleTimerDisabled = true
            if showDock {
                dockFocus = .newPattern
            }
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
            if showDock {
                showDock = false
                dockFocus = nil
            } else {
                showControls()
            }
        }
        .onMoveCommand { _ in
            guard !showDock else { return }
            showControls()
        }
        .sheet(isPresented: $showZenSheet) {
            TVZenOptionsSheet(settings: settings)
                .presentationBackground(BL.void)
        }
        .onChange(of: showZenSheet) { _, open in
            if !open && showDock {
                dockFocus = .ambientOptions
            }
        }
        .onChange(of: showDock) { _, expanded in
            if expanded {
                dockFocus = .newPattern
            } else {
                dockFocus = nil
            }
        }
    }

    // MARK: - Ambient hint (panels hidden)

    private var ambientHintChrome: some View {
        HStack {
            Spacer(minLength: 0)
            Label("Menu for controls", systemImage: "rectangle.expand.vertical")
                .font(.body.weight(.semibold))
                .foregroundStyle(BL.paper.opacity(0.88))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background {
                    Capsule()
                        .fill(BL.void.opacity(0.72))
                        .overlay(Capsule().strokeBorder(BL.rule, lineWidth: 1))
                }
                .shadow(color: .black.opacity(0.8), radius: 12)
        }
        .padding(.horizontal, 48)
        .padding(.top, 56)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Controls hidden. Press Menu or a directional button on the Siri Remote to show controls.")
    }

    // MARK: - Dock

    private var tvControlDock: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                BLDot(color: BL.accent(for: settings.paletteId), size: 12)
                Text("Mandaza")
                    .font(.bl(28, weight: .semibold))
                    .foregroundStyle(BL.highlight)
                Spacer(minLength: 0)
                Text(seedPrefix)
                    .font(.blMono(18))
                    .foregroundStyle(BL.muted)
            }

            Button {
                noteUserInteraction()
                regenerate()
            } label: {
                Label("New pattern", systemImage: "arrow.triangle.2.circlepath")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(BL.accent(for: settings.paletteId))
            .focused($dockFocus, equals: .newPattern)
            .accessibilityHint("Generates a new random mandala.")

            HStack(spacing: 20) {
                glowToggleButton

                Button {
                    noteUserInteraction()
                    showZenSheet = true
                } label: {
                    Label("Ambient options", systemImage: "moon.stars")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .focused($dockFocus, equals: .ambientOptions)
                .accessibilityHint("Zen mode, clock, and automatic new patterns.")

                Spacer(minLength: 0)
            }

            paletteCarousel

            remoteLegend
        }
        .padding(36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(BL.void.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(BL.rule, lineWidth: 1)
                )
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 48)
        .safeAreaPadding(.horizontal, 12)
        .focusSection()
        .defaultFocus($dockFocus, .newPattern)
    }

    private var glowToggleButton: some View {
        Button {
            noteUserInteraction()
            settings.glow.toggle()
        } label: {
            Label(
                settings.glow ? "Glow on" : "Glow off",
                systemImage: settings.glow ? "sparkles" : "sparkles.slash"
            )
            .font(.body.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .focused($dockFocus, equals: .glow)
        .accessibilityHint("Adds a soft glow around strokes. Uses more GPU when on.")
    }

    private var remoteLegend: some View {
        VStack(alignment: .leading, spacing: 14) {
            legendRow(symbol: "playpause.fill", title: "Play Pause", subtitle: "New pattern")
            legendRow(symbol: "rectangle.portrait.and.arrow.right", title: "Menu", subtitle: showDock ? "Hide controls" : "Show controls")
            Text("Controls stay put until you hide them.")
                .font(.callout.weight(.medium))
                .foregroundStyle(BL.muted)
        }
        .padding(.top, 4)
    }

    private func legendRow(symbol: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(BL.accent(for: settings.paletteId))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BL.paper)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(BL.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    private var paletteCarousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Palettes")
                .font(.bl(18, weight: .semibold))
                .foregroundStyle(BL.highlight)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 210, maximum: 260), spacing: 18)],
                alignment: .leading,
                spacing: 18
            ) {
                ForEach(Palette.all) { palette in
                    let selected = settings.paletteId == palette.id
                    Button {
                        noteUserInteraction()
                        settings.paletteId = palette.id
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Text(palette.name)
                                    .font(.bl(20, weight: .medium))
                                    .foregroundStyle(BL.paper)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.76)
                                Spacer(minLength: 0)
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(BL.accent(for: palette.id))
                                }
                            }
                            paletteSwatch(for: palette)
                                .frame(height: 12)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                    }
                    .buttonStyle(.card)
                    .focused($dockFocus, equals: .palette(palette.id))
                    .accessibilityLabel("\(palette.name) palette\(selected ? ", selected" : "")")
                    .accessibilityHint("Applies this color palette to new patterns.")
                }
            }
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

    // MARK: - Transitions

    private func ambientTransition() -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
    }

    private func dockTransition() -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    // MARK: - Dock visibility

    private func noteUserInteraction() {
        if !showDock {
            showControls()
        }
    }

    private func showControls(focus: TVDockFocus = .newPattern) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            showDock = true
        }
        dockFocus = focus
    }

    // MARK: - Engine config

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
            noteUserInteraction()
        }
    }
}

// MARK: - Focus

private enum TVDockFocus: Hashable {
    case newPattern
    case glow
    case ambientOptions
    case palette(String)
}

// MARK: - Zen options sheet

private struct TVZenOptionsSheet: View {

    @Bindable var settings: MandazaSettings
    @Environment(\.dismiss) private var dismiss

    /// Preset seconds for loop interval (matches living-room tuning).
    private static let intervalPresets: [Double] = [6, 15, 30, 60, 120]

    @State private var intervalIndex: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Zen mode", isOn: $settings.zenMode)
                        .accessibilityHint("Ambient clock and optional automatic new patterns.")
                    Toggle("Show clock", isOn: $settings.zenShowClock)
                        .disabled(!settings.zenMode)
                    Toggle("Show seconds", isOn: $settings.zenShowSeconds)
                        .disabled(!settings.zenMode || !settings.zenShowClock)
                    Toggle("Show date", isOn: $settings.zenShowDate)
                        .disabled(!settings.zenMode || !settings.zenShowClock)
                } header: {
                    Text("Zen")
                }

                Section {
                    Toggle("Loop new patterns", isOn: $settings.zenAutoRegen)
                        .disabled(!settings.zenMode)
                    if settings.zenAutoRegen && settings.zenMode {
                        Picker("Loop interval", selection: $intervalIndex) {
                            ForEach(Self.intervalPresets.indices, id: \.self) { i in
                                Text(intervalLabel(Self.intervalPresets[i]))
                                    .tag(i)
                            }
                        }
                        .pickerStyle(.inline)
                        .accessibilityHint("How long to wait after a pattern finishes before generating another.")
                        .onChange(of: intervalIndex) { _, i in
                            settings.zenAutoRegenSeconds = Self.intervalPresets[i]
                        }
                    }
                } header: {
                    Text("Automatic patterns")
                }
            }
            .background(BL.void.ignoresSafeArea())
            .navigationTitle("Ambient options")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            syncIntervalIndex()
        }
        .onChange(of: settings.zenAutoRegenSeconds) { _, _ in
            syncIntervalIndex()
        }
    }

    private func syncIntervalIndex() {
        let v = settings.zenAutoRegenSeconds
        if let exact = Self.intervalPresets.firstIndex(where: { abs($0 - v) < 0.01 }) {
            intervalIndex = exact
        } else {
            intervalIndex = nearestPresetIndex(to: v)
            settings.zenAutoRegenSeconds = Self.intervalPresets[intervalIndex]
        }
    }

    private func nearestPresetIndex(to value: Double) -> Int {
        var best = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, p) in Self.intervalPresets.enumerated() {
            let d = abs(p - value)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return best
    }

    private func intervalLabel(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s >= 60 {
            let m = s / 60
            return m == 1 ? "1 minute" : "\(m) minutes"
        }
        return "\(s) seconds"
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
        .accessibilityLabel(clockAccessibilityLabel())
    }

    private func timeString(_ date: Date) -> String {
        let style: Date.FormatStyle = showSeconds
            ? .dateTime.hour().minute().second()
            : .dateTime.hour().minute()
        return date.formatted(style)
    }

    private func clockAccessibilityLabel() -> String {
        var parts = ["Clock"]
        if showDate {
            parts.append("with date")
        }
        if showSeconds {
            parts.append("with seconds")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    TVContentView()
}
