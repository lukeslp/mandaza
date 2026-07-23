/*
 File Purpose: Fullscreen tvOS ambient mandala view with a minimal quick-control
 rail, deterministic remote recovery, Zen clock, and App Group–backed settings.

 Primary Components:
 - `TVContentView` — canvas host, idle suppressor, dock, Zen sheet, deep links.
 - `TVZenClockOverlay` — large clock/date overlay (Zen aesthetic).
 - `TVZenOptionsSheet` — Ambient Options form; Zen tuning in a tvOS-safe collapsible section.

 Inputs / Outputs:
 - Inputs: Siri Remote (Play/Pause, Menu, touch surface click, directional swipe),
   `mandaza://` URLs, shared settings.
 - Outputs: renders live `MandazaCanvas`, persists toggles via `MandazaSettings`.
 */

#if os(tvOS)
import SwiftUI
import UIKit

struct TVContentView: View {

    @State private var settings = MandazaSettings.shared
    @State private var configOverride: EngineConfig?
    @State private var seed = UUID().uuidString
    @State private var canvasSize: CGSize = .zero

    /// Menu toggles dock visibility (explicit chrome vs ambient-only).
    @State private var showDock = true
    @State private var showZenSheet = false

    @State private var autoRegenTask: Task<Void, Never>? = nil
    @State private var dockIdleTask: Task<Void, Never>? = nil
    @State private var ambientHintTask: Task<Void, Never>? = nil
    @State private var lastIdle: Bool = false
    @State private var showAmbientHint: Bool = false

    @FocusState private var dockFocus: TVDockFocus?
    /// When the dock is hidden, tvOS must still have a focused view or Menu/Select/Play
    /// never reach SwiftUI and the system sends the user to the Home screen.
    @FocusState private var ambientSurfaceFocused: Bool

    /// First-run defaults tuned for Apple TV ambient viewing (local UserDefaults only).
    private static let tvDefaultsAppliedKey = "MandazaTV.appliedAmbientDefaults.v1"

    /// Hide dock after focus idle while expanded (living-room ambient).
    private let dockAutoHideDelay: Duration = .seconds(18)

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var assistiveTechnologyRunning: Bool {
        UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    BL.canvasGround(for: settings.canvasTheme)
                    MandazaCanvas(
                        size: geo.size,
                        seed: seed,
                        paletteId: MandazaScreenshot.palette(settings.paletteId),
                        config: engineConfigForTV(),
                        onIdleChange: handleIdleChange(_:),
                        parallaxDepthContrast: settings.zenTiltDepth,
                        parallaxInvertDepth: settings.zenTiltInvertDepth,
                        theme: settings.canvasTheme
                    )
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, new in canvasSize = new }
            }
            .ignoresSafeArea()
            .accessibilitySortPriority(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mandaza canvas")
            .accessibilityHint("Shows animated patterns. Click the touch surface for a new pattern. Press Play Pause for a new pattern. Press Menu to show or hide controls.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { regenerate() }

            if settings.zenMode && settings.zenShowClock {
                VStack(spacing: 0) {
                    TVZenClockOverlay(
                        showSeconds: settings.zenShowSeconds,
                        showDate: settings.zenShowDate,
                        accent: BL.accent(for: settings.paletteId),
                        clockOpacity: settings.zenClockOpacity,
                        containerOpacity: settings.zenClockContainerOpacity,
                        fontStyle: settings.zenClockFontStyle,
                        fontWeight: settings.zenClockFontWeight,
                        position: settings.zenClockPosition
                    )
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
                .accessibilitySortPriority(2)
                .transition(ambientTransition())
            }

            // Tiny focus sink when chrome is hidden — keeps remote events in-app without
            // painting a full-screen focused overlay over the artwork.
            if !showDock && !showZenSheet {
                Button {
                    regenerate()
                } label: {
                    Color.clear
                        .frame(width: 1, height: 1)
                }
                .buttonStyle(.plain)
                .focused($ambientSurfaceFocused)
                .focusEffectDisabled()
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            VStack(spacing: 0) {
                if showAmbientHint && !showDock {
                    ambientHintChrome
                        .accessibilitySortPriority(4)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if showDock {
                    tvControlDock
                        .accessibilitySortPriority(3)
                        .transition(dockTransition())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: showDock)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showAmbientHint)
        }
        .onAppear {
            applyTVAmbientDefaultsIfNeeded()
            UIApplication.shared.isIdleTimerDisabled = true
            if showDock {
                dockFocus = .newPattern
                resetDockIdleTimerIfNeeded()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            autoRegenTask?.cancel()
            dockIdleTask?.cancel()
            ambientHintTask?.cancel()
        }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .onReceive(NotificationCenter.default.publisher(
            for: UIAccessibility.voiceOverStatusDidChangeNotification
        )) { _ in handleAssistiveTechnologyChange() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIAccessibility.switchControlStatusDidChangeNotification
        )) { _ in handleAssistiveTechnologyChange() }
        .onChange(of: settings.zenMode) { _, on in
            if !on || !settings.zenAutoRegen {
                autoRegenTask?.cancel()
            } else if lastIdle {
                handleIdleChange(true)
            }
        }
        .onChange(of: settings.zenAutoRegen) { _, on in
            if !on || !settings.zenMode {
                autoRegenTask?.cancel()
            } else if lastIdle {
                handleIdleChange(true)
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced {
                autoRegenTask?.cancel()
            } else if lastIdle, settings.zenMode, settings.zenAutoRegen {
                handleIdleChange(true)
            }
        }
        .onOpenURL { handleIncomingURL($0) }
        .onPlayPauseCommand {
            if showDock { resetDockIdleTimerIfNeeded() }
            regenerate()
        }
        .onExitCommand {
            if showZenSheet {
                showZenSheet = false
                return
            }
            dockIdleTask?.cancel()
            if showDock {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                    showDock = false
                }
                dockFocus = nil
            } else {
                recoverControlsFromRemote()
            }
        }
        .onMoveCommand { _ in
            guard !showDock else { return }
            recoverControlsFromRemote()
        }
        .sheet(isPresented: $showZenSheet) {
            TVZenOptionsSheet(settings: settings)
                .presentationBackground(BL.void)
        }
        .onChange(of: showZenSheet) { _, open in
            if open {
                configOverride = nil
                ambientSurfaceFocused = false
                dockIdleTask?.cancel()
            } else if showDock {
                dockFocus = .ambientOptions
                resetDockIdleTimerIfNeeded()
            } else {
                scheduleAmbientSurfaceFocus()
            }
        }
        .onChange(of: showDock) { _, expanded in
            if expanded {
                ambientSurfaceFocused = false
                ambientHintTask?.cancel()
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { showAmbientHint = false }
                dockFocus = .newPattern
                resetDockIdleTimerIfNeeded()
            } else {
                dockIdleTask?.cancel()
                dockFocus = nil
                withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) { showAmbientHint = true }
                scheduleAmbientHintDismiss()
                scheduleAmbientSurfaceFocus()
            }
        }
        .onChange(of: dockFocus) { _, _ in
            if showDock && !showZenSheet {
                resetDockIdleTimerIfNeeded()
            }
        }
    }

    // MARK: - Ambient hint (panels hidden)

    /// Brief, top-aligned chip so ambient art stays primary (not full-screen chrome).
    private var ambientHintChrome: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.compress.vertical")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(BL.paper.opacity(0.95))
            Text("Menu or swipe for controls")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BL.highlight)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(BL.void.opacity(0.82))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(BL.rule.opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.55), radius: 10, y: 2)
        .frame(maxWidth: 520)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ambient mode. Press Menu or swipe on the touch surface to show controls. Click for a new pattern.")
    }

    // MARK: - Dock

    private var tvControlDock: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                BLDot(color: BL.accent(for: settings.paletteId), size: 12)
                Text("Mandaza Ambient")
                    .font(.bl(22, weight: .semibold))
                    .foregroundStyle(BL.highlight)
                Spacer(minLength: 0)
                Text(seedPrefix)
                    .font(.blMono(13))
                    .foregroundStyle(BL.muted)
            }

            HStack(spacing: 12) {
                Button {
                    noteUserInteraction()
                    regenerate()
                } label: {
                    Label("New", systemImage: "sparkles")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 132)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(BL.accent(for: settings.paletteId))
                .focused($dockFocus, equals: .newPattern)
                .accessibilityHint("Generates a new random mandala.")

                Button {
                    noteUserInteraction()
                    settings.zenMode.toggle()
                } label: {
                    Label(settings.zenMode ? "Zen On" : "Zen Off",
                          systemImage: settings.zenMode ? "moon.stars.fill" : "moon.stars")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .focused($dockFocus, equals: .zenMode)
                .accessibilityHint("Turns ambient Zen clock mode on or off.")

                Button {
                    noteUserInteraction()
                    showZenSheet = true
                } label: {
                    Label("Ambient Options", systemImage: "slider.horizontal.3")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .focused($dockFocus, equals: .ambientOptions)
                .accessibilityHint("Open detailed ambient settings.")

                Spacer(minLength: 0)
            }

            compactPaletteRow
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(BL.void.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(BL.rule, lineWidth: 1)
                )
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 36)
        .safeAreaPadding(.horizontal, 12)
        .focusSection()
        .defaultFocus($dockFocus, .newPattern)
    }

    private var compactPaletteRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Palettes")
                .font(.bl(15, weight: .semibold))
                .foregroundStyle(BL.highlight)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Palette.all) { palette in
                        paletteChip(palette)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func paletteChip(_ palette: Palette) -> some View {
        let selected = settings.paletteId == palette.id
        return Button {
            noteUserInteraction()
            settings.paletteId = palette.id
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(BL.accent(for: palette.id))
                    .frame(width: 8, height: 8)
                Text(palette.name)
                    .font(.bl(14, weight: .medium))
                    .lineLimit(1)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
            }
            .foregroundStyle(selected ? BL.highlight : BL.paper)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? BL.deep.opacity(0.95) : BL.deep.opacity(0.6))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(selected ? BL.accent(for: palette.id).opacity(0.6) : BL.rule, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focused($dockFocus, equals: .palette(palette.id))
        .accessibilityLabel("\(palette.name) palette\(selected ? ", selected" : "")")
        .accessibilityHint("Applies this color palette.")
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

    // MARK: - Dock visibility & idle hide

    private func noteUserInteraction() {
        if !showDock {
            showControls()
        } else {
            resetDockIdleTimerIfNeeded()
        }
    }

    private func showControls(focus: TVDockFocus = .newPattern) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            showDock = true
        }
        ambientHintTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showAmbientHint = false }
        dockFocus = focus
        resetDockIdleTimerIfNeeded()
    }

    private func recoverControlsFromRemote() {
        showControls(focus: .newPattern)
    }

    private func scheduleAmbientHintDismiss() {
        ambientHintTask?.cancel()
        ambientHintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) { showAmbientHint = false }
        }
    }

    /// After the dock hides, move focus to the full-screen ambient control so Siri Remote
    /// Select / Menu / Play Pause / directional swipe reach SwiftUI instead of the system shell.
    private func scheduleAmbientSurfaceFocus() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            guard !showDock, !showZenSheet else { return }
            ambientSurfaceFocused = true
        }
    }

    private func resetDockIdleTimerIfNeeded() {
        dockIdleTask?.cancel()
        guard showDock, !showZenSheet, !assistiveTechnologyRunning else { return }
        dockIdleTask = Task { @MainActor in
            try? await Task.sleep(for: dockAutoHideDelay)
            guard !Task.isCancelled, showDock, !showZenSheet,
                  !assistiveTechnologyRunning else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                showDock = false
            }
            dockFocus = nil
        }
    }

    private func handleAssistiveTechnologyChange() {
        guard assistiveTechnologyRunning else {
            resetDockIdleTimerIfNeeded()
            return
        }
        dockIdleTask?.cancel()
        if !showDock { showControls() }
    }

    // MARK: - Engine config

    private func engineConfigForTV() -> EngineConfig {
        configOverride ?? settings.engineConfig()
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
        configOverride = nil
        seed = UUID().uuidString
        settings.randomizePatternLook(includePalette: settings.randomizePaletteOnRegenerate)
        if showDock { resetDockIdleTimerIfNeeded() }
    }

    private func handleIdleChange(_ idle: Bool) {
        lastIdle = idle
        autoRegenTask?.cancel()
        guard idle, settings.zenMode, settings.zenAutoRegen, !reduceMotion else { return }
        let wait = settings.zenAutoRegenSeconds
        autoRegenTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            if !Task.isCancelled, !reduceMotion { regenerate() }
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
            dockIdleTask?.cancel()
        @unknown default:
            break
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if let snapshot = MandazaDeepLink.snapshot(from: url) {
            seed = snapshot.seed
            settings.paletteId = snapshot.paletteId
            settings.applyLook(from: snapshot.config)
            configOverride = snapshot.config
            noteUserInteraction()
            return
        }
        guard let incomingSeed = MandazaDeepLink.seed(from: url) else { return }
        configOverride = nil
        seed = incomingSeed
        noteUserInteraction()
    }
}

// MARK: - Focus

private enum TVDockFocus: Hashable {
    case newPattern
    case zenMode
    case ambientOptions
    case palette(String)
}

// MARK: - Zen options sheet

private struct TVZenOptionsSheet: View {

    @Bindable var settings: MandazaSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Preset seconds for loop interval (matches living-room tuning).
    private static let intervalPresets: [Double] = [6, 15, 30, 60, 120]
    private static let opacityPresets: [Double] = [0.4, 0.55, 0.7, 0.85, 1.0]
    private static let containerOpacityPresets: [Double] = [0.0, 0.12, 0.2, 0.3, 0.4]
    private static let fontWeightPresets: [Double] = [0.1, 0.22, 0.34, 0.5, 0.66]
    private static let fontWeightLabels: [String] = fontWeightPresets.map { ZenClockTypography.weightLabel(for: $0) }

    @State private var intervalIndex: Int = 0
    @State private var opacityIndex: Int = 4
    @State private var containerOpacityIndex: Int = 0
    @State private var fontWeightIndex: Int = 0
    @State private var showZenDetails: Bool = false

    private var glowToggleBinding: Binding<Bool> {
        Binding(
            get: { settings.glow },
            set: { on in
                settings.glow = on
                if on { settings.glowStrength = 1.0 }
            }
        )
    }

    /// Keeps menu pickers and `syncStyleIndices` from fighting UIKit context-menu teardown on the same turn.
    private func scheduleSyncStyleIndices() {
        Task { @MainActor in
            syncStyleIndices()
        }
    }

    private func scheduleSyncIntervalIndex() {
        Task { @MainActor in
            syncIntervalIndex()
        }
    }

    private var loopIntervalSelection: Binding<Int> {
        Binding(
            get: { intervalIndex },
            set: { new in
                intervalIndex = new
                settings.zenAutoRegenSeconds = Self.intervalPresets[new]
            }
        )
    }

    private var fontWeightSelection: Binding<Int> {
        Binding(
            get: { fontWeightIndex },
            set: { new in
                fontWeightIndex = new
                settings.zenClockFontWeight = Self.fontWeightPresets[new]
            }
        )
    }

    private var clockOpacitySelection: Binding<Int> {
        Binding(
            get: { opacityIndex },
            set: { new in
                opacityIndex = new
                settings.zenClockOpacity = Self.opacityPresets[new]
            }
        )
    }

    private var containerOpacitySelection: Binding<Int> {
        Binding(
            get: { containerOpacityIndex },
            set: { new in
                containerOpacityIndex = new
                settings.zenClockContainerOpacity = Self.containerOpacityPresets[new]
            }
        )
    }

    @ViewBuilder
    private var zenControlsHeaderRow: some View {
        Button {
            showZenDetails.toggle()
        } label: {
            HStack {
                Text("Zen Controls")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showZenDetails ? 0 : -90))
                    .animation(reduceMotion ? nil : .default, value: showZenDetails)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Zen controls")
        .accessibilityValue(showZenDetails ? "Expanded" : "Collapsed")
        .accessibilityHint(showZenDetails ? "Collapse Zen tuning." : "Expand Zen tuning.")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Zen Mode", isOn: $settings.zenMode)
                        .accessibilityHint("Ambient clock and optional automatic new patterns.")

                    if settings.zenMode {
                        zenControlsHeaderRow
                        if showZenDetails {
                            zenLoopControls
                            zenClockToggles
                            zenClockStylePickers
                            zenClockOpacityPickers
                        }
                    }
                } header: {
                    Text("Zen")
                }

                Section {
                    Toggle("Randomize Palette on New", isOn: $settings.randomizePaletteOnRegenerate)
                        .accessibilityHint("When on, Play Pause or New picks a different palette.")
                    Toggle("Glow", isOn: glowToggleBinding)
                    Picker("Canvas", selection: Binding(
                        get: { settings.canvasTheme },
                        set: { settings.canvasTheme = $0 }
                    )) {
                        Text("Void").tag(CanvasTheme.void)
                        Text("Paper").tag(CanvasTheme.paper)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Pattern")
                }
            }
            .background(BL.void.ignoresSafeArea())
            .navigationTitle("Ambient Options")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            syncIntervalIndex()
            syncStyleIndices()
            showZenDetails = settings.zenMode
        }
        .onChange(of: settings.zenAutoRegenSeconds) { _, _ in
            scheduleSyncIntervalIndex()
        }
        .onChange(of: settings.zenClockOpacity) { _, _ in
            scheduleSyncStyleIndices()
        }
        .onChange(of: settings.zenClockContainerOpacity) { _, _ in
            scheduleSyncStyleIndices()
        }
        .onChange(of: settings.zenClockFontWeight) { _, _ in
            scheduleSyncStyleIndices()
        }
        .onChange(of: settings.zenMode) { _, enabled in
            showZenDetails = enabled
        }
    }

    @ViewBuilder
    private var zenLoopControls: some View {
        Toggle("Loop New Patterns", isOn: $settings.zenAutoRegen)
        if settings.zenAutoRegen {
            Picker("Loop interval", selection: loopIntervalSelection) {
                ForEach(Self.intervalPresets.indices, id: \.self) { i in
                    Text(intervalLabel(Self.intervalPresets[i]))
                        .tag(i)
                }
            }
            .pickerStyle(.menu)
            .accessibilityHint("How long to wait after a pattern finishes before generating another.")
        }
    }

    @ViewBuilder
    private var zenClockToggles: some View {
        Toggle("Show Clock", isOn: $settings.zenShowClock)
        Toggle("Show Seconds", isOn: $settings.zenShowSeconds)
            .disabled(!settings.zenShowClock)
        Toggle("Show Date", isOn: $settings.zenShowDate)
            .disabled(!settings.zenShowClock)
    }

    @ViewBuilder
    private var zenClockStylePickers: some View {
        Picker("Clock position", selection: $settings.zenClockPositionRaw) {
            Text("Top").tag(ZenClockPosition.top.rawValue)
            Text("Upper third").tag(ZenClockPosition.upperThird.rawValue)
            Text("Center").tag(ZenClockPosition.center.rawValue)
        }
        .pickerStyle(.menu)

        Picker("Font style", selection: $settings.zenClockFontStyleRaw) {
            Text("System").tag(ZenClockFontStyle.system.rawValue)
            Text("Rounded").tag(ZenClockFontStyle.rounded.rawValue)
            Text("Monospaced").tag(ZenClockFontStyle.monospaced.rawValue)
        }
        .pickerStyle(.menu)

        Picker("Font weight", selection: fontWeightSelection) {
            ForEach(Self.fontWeightPresets.indices, id: \.self) { i in
                Text(Self.fontWeightLabels[i]).tag(i)
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var zenClockOpacityPickers: some View {
        Picker("Clock opacity", selection: clockOpacitySelection) {
            ForEach(Self.opacityPresets.indices, id: \.self) { i in
                Text(opacityLabel(Self.opacityPresets[i])).tag(i)
            }
        }
        .pickerStyle(.menu)

        Picker("Container opacity", selection: containerOpacitySelection) {
            ForEach(Self.containerOpacityPresets.indices, id: \.self) { i in
                Text(opacityLabel(Self.containerOpacityPresets[i])).tag(i)
            }
        }
        .pickerStyle(.menu)
    }

    private func syncIntervalIndex() {
        let v = settings.zenAutoRegenSeconds
        if let exact = Self.intervalPresets.firstIndex(where: { abs($0 - v) < 0.01 }) {
            intervalIndex = exact
        } else {
            intervalIndex = nearestPresetIndex(to: v)
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

    private func syncStyleIndices() {
        opacityIndex = nearestIndex(in: Self.opacityPresets, to: settings.zenClockOpacity)
        containerOpacityIndex = nearestIndex(in: Self.containerOpacityPresets, to: settings.zenClockContainerOpacity)
        fontWeightIndex = nearestIndex(in: Self.fontWeightPresets, to: settings.zenClockFontWeight)
    }

    private func nearestIndex(in presets: [Double], to value: Double) -> Int {
        var best = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, p) in presets.enumerated() {
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

    private func opacityLabel(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }
}

// MARK: - Zen clock (tv-scale)

private struct TVZenClockOverlay: View {
    let showSeconds: Bool
    let showDate: Bool
    var accent: Color = BL.cyan
    let clockOpacity: Double
    let containerOpacity: Double
    let fontStyle: ZenClockFontStyle
    let fontWeight: Double
    let position: ZenClockPosition

    var body: some View {
        TimelineView(.periodic(from: .now, by: showSeconds ? 1 : 30)) { ctx in
            let now = ctx.date
            GeometryReader { geo in
                VStack(spacing: 16) {
                    Text(timeString(now))
                        .font(clockFont())
                        .tracking(-2)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(BL.highlight)
                        .shadow(color: .black.opacity(0.75), radius: 20)
                        .shadow(color: accent.opacity(0.35), radius: 32)
                    if showDate {
                        Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(dateFont())
                            .tracking(1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(BL.paper.opacity(0.75))
                            .shadow(color: .black.opacity(0.75), radius: 8)
                    }
                }
                .padding(.horizontal, 64)
                .padding(.vertical, 22)
                .background {
                    if containerOpacity > 0.001 {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.black.opacity(min(max(containerOpacity, 0), 0.85)))
                    }
                }
                .opacity(min(max(clockOpacity, 0.2), 1.0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignmentForPosition())
                .padding(.top, topPadding(height: geo.size.height))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(clockAccessibilityLabel(now))
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let style: Date.FormatStyle = showSeconds
            ? .dateTime.hour().minute().second()
            : .dateTime.hour().minute()
        return date.formatted(style)
    }

    private func clockAccessibilityLabel(_ date: Date) -> String {
        var parts = [timeString(date)]
        if showDate {
            parts.append(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        }
        return parts.joined(separator: ", ")
    }

    private func alignmentForPosition() -> Alignment {
        switch position {
        case .top, .upperThird:
            return .top
        case .center:
            return .center
        case .lowerThird:
            return .bottom
        case .topLeading:
            return .topLeading
        case .topTrailing:
            return .topTrailing
        case .bottomLeading:
            return .bottomLeading
        case .bottomTrailing:
            return .bottomTrailing
        }
    }

    private func topPadding(height: CGFloat) -> CGFloat {
        switch position {
        case .top, .topLeading, .topTrailing:
            return 72
        case .upperThird:
            return max(72, height * 0.16)
        case .center, .lowerThird, .bottomLeading, .bottomTrailing:
            return 0
        }
    }

    private func clockFont() -> Font {
        .system(size: 168, weight: ZenClockTypography.fontWeight(for: fontWeight), design: mappedDesign(fontStyle))
    }

    private func dateFont() -> Font {
        .system(size: 26, weight: .light, design: mappedDesign(fontStyle))
    }

    private func mappedDesign(_ style: ZenClockFontStyle) -> Font.Design {
        switch style {
        case .system: return .default
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        case .serif: return .serif
        case .condensed: return .default
        }
    }
}

#Preview {
    TVContentView()
}
#endif
