// File Purpose: Hosts Mandaza's primary iOS experience, including the live canvas,
// Zen controls, settings, export flow, recents, favorites, and watch handoff.
// Primary Components: ContentView, SettingsSheet, FavoritesGrid, ZenClockOverlay,
// Toast, and small reusable control views.
// I/O: Reads and writes MandazaSettings, user gestures, scene phase, motion/audio
// sources, and export requests; outputs SwiftUI UI, saved images, widget reloads,
// toasts, accessibility announcements, and watch sync messages.

#if !os(tvOS)
import SwiftUI
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

struct ContentView: View {

    // Shared, App Group-backed settings (single source of truth for app + widgets).
    @State private var settings = MandazaSettings.shared

    // Ephemeral state — purely view-local.
    @State private var seed = UUID().uuidString
    /// Exact external/favorite config, retained even when it cannot be mapped
    /// losslessly onto the simplified settings controls.
    @State private var configOverride: EngineConfig?
    @State private var canvasSize: CGSize = .zero
    @State private var showSettings = false
    @State private var exportInProgress = false
    @State private var exportAlert: ExportAlert? = nil
    @State private var toastMessage: String? = nil
    @State private var toastClearTask: Task<Void, Never>? = nil
    @State private var autoRegenTask: Task<Void, Never>? = nil
    @State private var lastIdle: Bool = false

    /// The bottom shelf fades after a short idle period. Once faded, the next
    /// screen tap only restores the controls; while visible, a canvas tap
    /// cycles the visualization.
    @State private var controlsFaded = false
    @State private var controlsFadeTask: Task<Void, Never>? = nil
    private let controlsFadeDelay: Duration = .seconds(2.8)

    /// Ring buffer of the last 5 mandalas the user generated but didn't save.
    /// Recoverable via long-press on the Regenerate button. Transient — not
    /// persisted across launches (favorites is the durable affordance).
    @State private var recents: [MandazaSnapshot] = []
    @State private var showRecents = false
    private let recentsCap = 5

    /// Music responsivity: microphone-driven modulation of the live canvas,
    /// active only while Zen Mode is on and `settings.musicResponsivity` is
    /// set. The reactor is foreground-only; scenePhase handling stops/resumes.
    @State private var reactor = AudioReactor()

    /// Device-tilt parallax source. Runs whenever enabled; Zen additionally
    /// mixes in faint ambient sway so depth remains visible at rest.
    @State private var tilt = TiltProvider()

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    // MARK: - Body

    var body: some View {
        ZStack {
            // Layer 1 — edge-to-edge canvas. Parallax is applied per-stroke
            // inside MandazaCanvas (luminance depth) so CoreMotion never
            // invalidates the TimelineView host.
            GeometryReader { geo in
                ZStack {
                    BL.canvasGround(for: settings.canvasTheme)
                    MandazaCanvas(size: geo.size,
                                  seed: seed,
                                  paletteId: MandazaScreenshot.palette(settings.paletteId),
                                  config: effectiveConfig,
                                  reactivity: settings.reactivity,
                                  onIdleChange: handleIdleChange(_:),
                                  modulationSource: reactor.source,
                                  parallaxSource: (settings.zenTiltEnabled && !reduceMotion)
                                      ? tilt : nil,
                                  parallaxDepthContrast: settings.zenTiltDepth,
                                  parallaxInvertDepth: settings.zenTiltInvertDepth,
                                  theme: settings.canvasTheme)
                }
                .onAppear { canvasSize = geo.size; tilt.viewSize = geo.size }
                .onChange(of: geo.size) { _, new in canvasSize = new; tilt.viewSize = new }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.7)
                    .onEnded { _ in canvasLongPressed() }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded { canvasTapped() }
            )
            .allowsHitTesting(!showSettings && !exportInProgress)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mandaza canvas")
            .accessibilityHint(canvasA11yHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { canvasTapped() }
            .accessibilityHidden(exportInProgress)

            // Layer 2 — clock overlay (mid-depth UIKit parallax).
            if settings.zenMode, settings.zenShowClock {
                ParallaxHost(provider: tilt, multiplier: CGFloat(0.35 + 0.45 * settings.zenTiltAmount)) {
                    ZenClockOverlay(showSeconds: settings.zenShowSeconds,
                                    showDate: settings.zenShowDate,
                                    accent: BL.accent(for: settings.paletteId),
                                    clockOpacity: settings.zenClockOpacity,
                                    containerOpacity: settings.zenClockContainerOpacity,
                                    fontStyle: settings.zenClockFontStyle,
                                    fontWeight: settings.zenClockFontWeight,
                                    position: MandazaScreenshot.clockPosition(settings.zenClockPosition),
                                    form: MandazaScreenshot.clockForm(settings.zenClockForm),
                                    sizeScale: settings.zenClockSizeScale)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // Layer 3 — grounded controls. The shelf remains a continuous
            // bottom surface and fades down after idle time.
            VStack(spacing: 8) {
                Spacer()
                if showRecents, !recents.isEmpty {
                    recentsStrip
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                controlBar
            }
            .opacity(controlsFaded ? 0 : 1)
            .allowsHitTesting(!controlsFaded)
            .accessibilityHidden(exportInProgress)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: controlsFaded)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showRecents)

            if controlsFaded {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        restoreControls()
                    }
                    .accessibilityElement()
                    .accessibilityLabel("Show controls")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Restores the bottom toolbar.")
            }

            // Layer 4 — export progress dim.
            if exportInProgress {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView {
                    BLCaption("saving", tint: BL.accent(for: settings.paletteId))
                }
                .tint(BL.accent(for: settings.paletteId))
                .padding(24)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(BL.deep)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(BL.rule, lineWidth: 1))
                }
                .accessibilityLabel("Saving image")
            }
        }
        .safeAreaInset(edge: .top) {
            if let message = toastMessage {
                Toast(text: message, accent: BL.accent(for: settings.paletteId))
                    .padding(.top, 4)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(settings: settings,
                          loadFavorite: loadFavorite(_:),
                          reactor: reactor,
                          toggleReactor: applyMusicResponsivity)
        }
        .alert(item: $exportAlert) { alert in
            switch alert.kind {
            case .permissionDenied:
                return Alert(
                    title: Text("Photos Access Needed"),
                    message: Text("Mandaza needs permission to add this image to your Photo Library."),
                    primaryButton: .default(Text("Open Settings"), action: openAppSettings),
                    secondaryButton: .cancel())
            case .renderFailed:
                return Alert(
                    title: Text("Couldn't Save"),
                    message: Text("The image couldn't be rendered. Try a smaller resolution."),
                    primaryButton: .default(Text("Try Smaller"), action: exportFallback),
                    secondaryButton: .cancel())
            case .saveFailed(let message):
                return Alert(
                    title: Text("Couldn't Save"),
                    message: Text(message),
                    dismissButton: .default(Text("OK")))
            }
        }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .onReceive(NotificationCenter.default.publisher(
            for: UIAccessibility.voiceOverStatusDidChangeNotification
        )) { _ in handleAssistiveTechnologyChange() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIAccessibility.switchControlStatusDidChangeNotification
        )) { _ in handleAssistiveTechnologyChange() }
        .onChange(of: settings.zenMode) { _, on in
            applyTilt()
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
        .onChange(of: settings.zenTiltEnabled) { _, _ in applyTilt() }
        .onChange(of: settings.zenTiltAmount) { _, _ in applyTilt() }
        .onChange(of: settings.zenTiltAxesRaw) { _, _ in applyTilt() }
        .onChange(of: reduceMotion) { _, reduced in
            applyTilt()
            if reduced {
                autoRegenTask?.cancel()
            } else if lastIdle, settings.zenMode, settings.zenAutoRegen {
                handleIdleChange(true)
            }
        }
        .onChange(of: showSettings) { _, isPresented in
            if !isPresented { noteInteraction() }
        }
        .onChange(of: exportInProgress) { _, inProgress in
            if !inProgress { noteInteraction() }
        }
        .onOpenURL { handleIncomingURL($0) }
        .onAppear {
            scheduleControlsFade()
            applyTilt()
            WatchSyncController.shared.activate()
            #if DEBUG
            if MandazaScreenshot.isMusicDemoActive {
                // Screenshot hook: force Zen + synthetic reactivity so captures
                // are reproducible without a live microphone.
                settings.zenMode = true
                reactor.source.startDemo()
            } else if settings.zenMode, settings.musicResponsivity, AudioReactor.micAvailable {
                Task { await reactor.start() }
            }
            #else
            if settings.zenMode, settings.musicResponsivity, AudioReactor.micAvailable {
                Task { await reactor.start() }
            }
            #endif
        }
        .onDisappear { controlsFadeTask?.cancel() }
        // Persist the user's Music Mode intent. Only a user-initiated stop
        // leaves the reactor .idle with isActive false — interruptions and
        // failures must not erase the preference (nor may the forced stop
        // on backgrounding, hence the scenePhase guard).
        .onChange(of: reactor.source.isActive) { _, active in
            if scenePhase == .active, active || reactor.state == .idle {
                settings.musicMode = active
            }
        }
        // Mirror look/behavior changes to the watch no matter which screen
        // they were made on (the controller debounces).
        .onChange(of: watchSyncFingerprint) { _, _ in
            if watchAvailable { WatchSyncController.shared.pushSettings(settings) }
        }
    }

    // MARK: - Canvas accessibility

    private var canvasA11yHint: String {
        if controlsFaded {
            return "Double tap to show the controls."
        } else if longPressEnabled {
            return "Double tap to generate a new pattern. Press and hold also generates a new pattern."
        } else {
            return "Double tap to generate a new pattern."
        }
    }

    private var canvasA11yTraits: AccessibilityTraits {
        // When AT is on, the canvas is not a button — it's a decorative image.
        // Don't promise gestures we won't honor.
        longPressEnabled ? .isButton : .isImage
    }

    /// Long-press regenerate is disabled whenever VoiceOver or Switch Control
    /// is active — assistive tech users get the explicit button instead.
    private var longPressEnabled: Bool {
        !assistiveTechnologyRunning
    }

    private var assistiveTechnologyRunning: Bool {
        UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
    }

    private var effectiveConfig: EngineConfig {
        configOverride ?? settings.engineConfig()
    }

    // MARK: - Control bar

    private var controlBar: some View {
        let accent = BL.accent(for: settings.paletteId)
        return HStack(alignment: .center, spacing: 10) {
            // Footer order: History · Favorites · Zen (center) · Settings · Save.
            // "New" is gone — tapping the canvas generates a fresh mandala.
            dockButton(system: recents.isEmpty ? "clock" : "clock.arrow.circlepath",
                       label: "Previous",
                       accent: accent,
                       enabled: !recents.isEmpty) {
                noteInteraction()
                toggleRecents()
            }

            dockButton(system: favoriteIcon,
                       label: settings.isFavorite(seed: seed) ? "Saved" : "Favorite",
                       accent: settings.isFavorite(seed: seed) ? BL.pink : accent) {
                noteInteraction()
                toggleFavorite()
            }

            Button {
                toggleZen()
            } label: {
                zenCenterButton(accent: accent)
            }
            .accessibilityLabel(settings.zenMode ? "Exit Zen Mode" : "Enter Zen Mode")
            .accessibilityHint("Shows a fullscreen clock over the mandala and, when Music responsivity is on, moves the artwork with nearby sound.")
            .accessibilityValue(reactor.source.isActive ? "Music responsive" : "")
            .buttonStyle(.plain)

            dockButton(system: "slider.horizontal.3",
                       label: "Tune",
                       accent: accent) {
                noteInteraction()
                configOverride = nil
                showSettings = true
            }

            Menu {
                Button("Save Screen Size") {
                    noteInteraction()
                    exportFullScreen()
                }

                if watchAvailable {
                    Button {
                        noteInteraction()
                        sendCurrentToWatch()
                    } label: {
                        Label("Send to Watch", systemImage: "applewatch")
                    }
                }

                Section("Export Size") {
                    ForEach(ExportService.presets, id: \.label) { preset in
                        Button("\(preset.label)  •  \(Int(preset.size.width))×\(Int(preset.size.height))") {
                            noteInteraction()
                            exportAt(size: preset.size)
                        }
                    }
                }
            } label: {
                dockItem(system: "square.and.arrow.down",
                         label: "Save",
                         accent: accent)
                    .opacity(exportInProgress ? 0.35 : 1)
            }
            .accessibilityLabel("Save")
            .disabled(exportInProgress)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(BL.void.opacity(0.92))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(BL.rule)
                        .frame(height: 1)
                }
        }
    }

    // MARK: - Recents strip

    private var recentsStrip: some View {
        let accent = BL.accent(for: settings.paletteId)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                BLCaption("previous", tint: accent.opacity(0.85))
                Spacer()
                Button {
                    noteInteraction()
                    showRecents = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BL.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Hide previous patterns")
            }

            HStack(spacing: 10) {
                ForEach(recents) { snap in
                    Button {
                        noteInteraction()
                        loadRecent(snap)
                    } label: {
                        MandazaImageView(snapshot: snap,
                                         size: CGSize(width: 54, height: 72),
                                         scale: 2)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(BL.rule, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Load previous pattern")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(BL.void.opacity(0.96))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(accent.opacity(0.22))
                        .frame(height: 1)
                }
        }
    }

    private func dockButton(system: String,
                            label: String,
                            accent: Color,
                            enabled: Bool = true,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            dockItem(system: system, label: label, accent: accent)
                .opacity(enabled ? 1 : 0.35)
        }
        .accessibilityLabel(label)
        .disabled(!enabled)
        .buttonStyle(.plain)
    }

    private func dockItem(system: String,
                          label: String,
                          accent: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: system)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(BL.highlight)
                .frame(height: 26)

            Text(label)
                .font(.blMono(10, weight: .medium))
                .foregroundStyle(BL.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }

    private func zenCenterButton(accent: Color) -> some View {
        let on = settings.zenMode
        return VStack(spacing: 5) {
            Image(systemName: on ? "moon.stars.fill" : "moon.stars")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accent)
                .frame(height: 28)
                .shadow(color: accent.opacity(0.55), radius: 10)
            Text("Zen")
                .font(.blMono(10, weight: .semibold))
                .foregroundStyle(BL.highlight)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(alignment: .top) {
            Capsule()
                .fill(accent.opacity(on ? 0.18 : 0.10))
                .overlay(Capsule().strokeBorder(accent.opacity(on ? 0.6 : 0.35), lineWidth: 1))
                .frame(height: 50)
        }
        .overlay(alignment: .top) {
            MusicModePulseRing(reactor: reactor, accent: accent)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Zen toggle

    /// The center dock button owns Zen. Entering Zen starts the audio reactor
    /// only when the user opted into Music responsivity AND the platform has a
    /// microphone; leaving Zen always stops it.
    private func toggleZen() {
        noteInteraction()
        withAnimation { settings.zenMode.toggle() }
        applyMusicResponsivity()
        applyTilt()
        selectionFeedback()
    }

    /// Reconciles the tilt provider with current parallax settings. Parallax
    /// runs whenever enabled — in Zen or on the normal canvas. Respects
    /// Reduce Motion by stopping sampling. In Zen, a faint ambient sway keeps
    /// depth layers drifting while the device is still.
    private func applyTilt() {
        if settings.zenTiltEnabled, !reduceMotion {
            tilt.viewSize = canvasSize
            tilt.ambientSway = settings.zenMode
            tilt.start(amount: settings.zenTiltAmount, axes: settings.zenTiltAxes)
        } else {
            tilt.ambientSway = false
            tilt.stop()
        }
    }

    /// Reconciles the reactor with the current Zen + Music-responsivity state.
    /// Called on Zen toggle and when the Settings toggle changes.
    private func applyMusicResponsivity() {
        if settings.zenMode, settings.musicResponsivity, AudioReactor.micAvailable {
            if reactor.state == .idle || reactor.state == .interrupted {
                Task { await reactor.start() }
            }
        } else {
            reactor.stop()
        }
    }

    private var favoriteIcon: String {
        settings.isFavorite(seed: seed) ? "heart.fill" : "heart"
    }

    private func toggleRecents() {
        guard !recents.isEmpty else { return }
        showRecents.toggle()
        selectionFeedback()
    }

    // MARK: - Canvas gestures

    /// A canvas tap is the primary cycle gesture while controls are visible.
    /// Once the shelf has faded, the transparent tap catcher above handles
    /// the first tap so the artwork is not accidentally replaced.
    private func canvasTapped() {
        guard !showSettings, !exportInProgress else { return }
        guard !controlsFaded else {
            restoreControls()
            return
        }
        showRecents = false
        noteInteraction()
        regenerate()
    }

    /// 700ms long-press = regenerate. Opt-in power gesture, automatically
    /// disabled when VoiceOver or Switch Control is active so AT users get
    /// only the explicit Regenerate button.
    private func canvasLongPressed() {
        guard !showSettings, !exportInProgress else { return }
        guard longPressEnabled else { return }
        noteInteraction()
        regenerate()
        mediumImpactFeedback()
    }

    private func noteInteraction() {
        controlsFaded = false
        scheduleControlsFade()
    }

    private func restoreControls() {
        showRecents = false
        noteInteraction()
    }

    private func scheduleControlsFade() {
        controlsFadeTask?.cancel()
        // Don't auto-hide chrome while VoiceOver / Switch Control need persistent targets.
        guard !assistiveTechnologyRunning else { return }
        controlsFadeTask = Task { @MainActor in
            try? await Task.sleep(for: controlsFadeDelay)
            guard !Task.isCancelled, !showSettings, exportAlert == nil,
                  !exportInProgress, !assistiveTechnologyRunning else { return }
            showRecents = false
            controlsFaded = true
        }
    }

    private func handleAssistiveTechnologyChange() {
        if assistiveTechnologyRunning {
            controlsFadeTask?.cancel()
            controlsFaded = false
        } else {
            scheduleControlsFade()
        }
    }

    private func regenerate() {
        // Push the current snapshot into the Recents ring buffer BEFORE the
        // seed changes — so the artwork the user is about to overwrite is
        // recoverable.
        pushCurrentToRecents()
        configOverride = nil
        seed = UUID().uuidString
        settings.randomizePatternLook(includePalette: settings.randomizePaletteOnRegenerate)
        selectionFeedback()
        reloadWidgetTimelines()
    }

    // MARK: - Recents ring buffer

    private func pushCurrentToRecents() {
        let snap = MandazaSnapshot(seed: seed,
                                   paletteId: settings.paletteId,
                                   config: effectiveConfig)
        // De-dupe: if user oscillates back to a recent seed, don't re-record it.
        recents.removeAll { $0.seed == snap.seed }
        recents.insert(snap, at: 0)
        if recents.count > recentsCap { recents = Array(recents.prefix(recentsCap)) }
    }

    private func loadRecent(_ snap: MandazaSnapshot) {
        // Loading a recent should NOT push the current into recents (it's
        // already there if it was just-generated).
        seed = snap.seed
        settings.paletteId = snap.paletteId
        settings.applyLook(from: snap.config)
        configOverride = snap.config
        showRecents = false
        selectionFeedback()
    }

    // MARK: - Favorites

    private func toggleFavorite() {
        let now = settings.toggleFavorite(seed: seed,
                                          paletteId: settings.paletteId,
                                          config: effectiveConfig)
        showToast(now ? "Saved to Favorites" : "Removed from Favorites")
        reloadWidgetTimelines()
        selectionFeedback()
    }

    private func loadFavorite(_ snapshot: MandazaSnapshot) {
        seed = snapshot.seed
        settings.paletteId = snapshot.paletteId
        settings.applyLook(from: snapshot.config)
        configOverride = snapshot.config
    }

    private func selectionFeedback() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func mediumImpactFeedback() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Zen / scenePhase

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
            if lastIdle, settings.zenMode, settings.zenAutoRegen, !reduceMotion {
                handleIdleChange(true)
            }
            if settings.zenMode, settings.musicResponsivity, AudioReactor.micAvailable,
               reactor.state == .idle || reactor.state == .interrupted {
                Task { await reactor.start() }
            }
            if watchAvailable {
                WatchSyncController.shared.pushSettings(settings)
            }
            applyTilt()
        case .background, .inactive:
            autoRegenTask?.cancel()
            reactor.stop()
            tilt.stop()
        @unknown default:
            break
        }
    }

    // MARK: - Watch

    private var watchAvailable: Bool {
        WatchSyncController.shared.isPaired && WatchSyncController.shared.isWatchAppInstalled
    }

    /// One value covering every watch-relevant setting; a single onChange
    /// pushes on any change (mirrors WatchSettingsView.syncFingerprint).
    private var watchSyncFingerprint: String {
        WatchSync.settingsFingerprint(from: settings)
    }

    private func sendCurrentToWatch() {
        let snap = MandazaSnapshot(seed: seed,
                                   paletteId: settings.paletteId,
                                   config: effectiveConfig)
        WatchSyncController.shared.send(snapshot: snap)
        showToast("Sent to Watch")
        selectionFeedback()
    }

    private func handleIncomingURL(_ url: URL) {
        if let snapshot = MandazaDeepLink.snapshot(from: url) {
            seed = snapshot.seed
            settings.paletteId = snapshot.paletteId
            settings.applyLook(from: snapshot.config)
            configOverride = snapshot.config
            return
        }
        guard let incomingSeed = MandazaDeepLink.seed(from: url) else { return }
        configOverride = nil
        seed = incomingSeed
    }

    // MARK: - Export

    private func exportFullScreen() {
        guard canvasSize != .zero else { return }
        let pixelSize = CGSize(width: canvasSize.width * displayScale,
                               height: canvasSize.height * displayScale)
        exportAt(size: pixelSize)
    }

    private func exportFallback() {
        exportAt(size: CGSize(width: 1170, height: 2532))
    }

    private func exportAt(size: CGSize) {
        guard !exportInProgress else { return }
        exportInProgress = true
        let s = seed
        let pid = settings.paletteId
        let cfg = effectiveConfig

        Task.detached(priority: .userInitiated) {
            let image = MandazaEngine.renderImage(seed: s,
                                                  paletteId: pid,
                                                  config: cfg,
                                                  size: size)
            await MainActor.run { handleRenderedImage(image) }
        }
    }

    @MainActor
    private func handleRenderedImage(_ image: UIImage?) {
        guard let image = image else {
            exportInProgress = false
            exportAlert = .renderFailed
            return
        }
        Task { @MainActor in
            defer { exportInProgress = false }
            do {
                try await ExportService.saveToPhotos(image)
                showToast("Saved to Photos")
            } catch ExportError.noPermission {
                exportAlert = .permissionDenied
            } catch {
                exportAlert = .saveFailed(message: error.localizedDescription)
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        toastMessage = message
        UIAccessibility.post(notification: .announcement, argument: message)
        toastClearTask?.cancel()
        toastClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { toastMessage = nil }
        }
    }
}

// MARK: - Export alert

private enum ExportAlertKind {
    case permissionDenied
    case renderFailed
    case saveFailed(message: String)
}

private struct ExportAlert: Identifiable {
    let id = UUID()
    let kind: ExportAlertKind
    static let permissionDenied = ExportAlert(kind: .permissionDenied)
    static let renderFailed     = ExportAlert(kind: .renderFailed)
    static func saveFailed(message: String) -> ExportAlert {
        ExportAlert(kind: .saveFailed(message: message))
    }
}

// MARK: - Settings sheet

private struct SettingsSheet: View {
    private static let websiteURL = URL(string: "https://dr.eamer.dev")

    @Bindable var settings: MandazaSettings
    let loadFavorite: (MandazaSnapshot) -> Void
    var reactor: AudioReactor
    /// Reconciles the live reactor with the current Zen + Music-responsivity
    /// state — invoked by the host when the responsivity toggle changes.
    let toggleReactor: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var clockFormBinding: Binding<ZenClockForm> {
        Binding(
            get: { settings.zenClockForm },
            set: { settings.zenClockForm = $0 }
        )
    }

    private var clockFontStyleBinding: Binding<ZenClockFontStyle> {
        Binding(
            get: { settings.zenClockFontStyle },
            set: { settings.zenClockFontStyle = $0 }
        )
    }

    private var clockPositionBinding: Binding<ZenClockPosition> {
        Binding(
            get: { settings.zenClockPosition },
            set: { settings.zenClockPosition = $0 }
        )
    }

    private var tiltAxesBinding: Binding<ZenTiltAxes> {
        Binding(
            get: { settings.zenTiltAxes },
            set: { settings.zenTiltAxes = $0 }
        )
    }

    private var canvasThemeBinding: Binding<CanvasTheme> {
        Binding(
            get: { settings.canvasTheme },
            set: { settings.canvasTheme = $0 }
        )
    }

    /// Turning Glow on from settings uses full-strength bloom; random New uses a softer band.
    /// Tracks explicit user intent so randomizePatternLook never re-enables glow against their preference.
    private var glowToggleBinding: Binding<Bool> {
        Binding(
            get: { settings.glow },
            set: { on in
                settings.glow = on
                settings.glowUserDisabled = !on
                if on { settings.glowStrength = 1.0 }
            }
        )
    }

    var body: some View {
        let accent = BL.accent(for: settings.paletteId)
        return NavigationStack {
            Form {
                Section {
                    Toggle("Zen Mode", isOn: $settings.zenMode.animation())
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)
                } header: {
                    blHeader("Zen Mode", accent: accent)
                } footer: {
                    if !settings.zenMode {
                        Text("Turn on Zen to show a clock over the mandala and optional auto patterns.")
                            .font(.bl(12))
                            .foregroundStyle(BL.muted)
                    }
                }
                .listRowBackground(BL.deep)

                #if !os(tvOS)
                Section {
                    Toggle("Music responsivity", isOn: $settings.musicResponsivity)
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)
                        .onChange(of: settings.musicResponsivity) { _, _ in toggleReactor() }
                    if settings.musicResponsivity {
                        LabeledSlider(title: "Reactivity",
                                      value: $settings.reactivity,
                                      range: 0.0 ... 1.0,
                                      accent: accent,
                                      format: { reactivityLabel(for: $0) })
                    }
                    if reactor.state == .denied {
                        Button("Open Settings to Allow Microphone") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                        .font(.bl(15))
                        .foregroundStyle(accent)
                    }
                } header: {
                    blHeader("Music", accent: accent)
                } footer: {
                    Text("In Zen Mode, Mandaza listens through the microphone so the mandala moves with nearby music — audio is never recorded or stored.")
                        .font(.bl(12))
                        .foregroundStyle(BL.muted)
                }
                .listRowBackground(BL.deep)

                Section {
                    Toggle("Tilt parallax", isOn: $settings.zenTiltEnabled)
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)
                    if settings.zenTiltEnabled {
                        LabeledSlider(title: "Amount",
                                      value: $settings.zenTiltAmount,
                                      range: 0.05 ... 1.0,
                                      accent: accent,
                                      format: { parallaxAmountLabel(for: $0) })
                        LabeledSlider(title: "Depth layers",
                                      value: $settings.zenTiltDepth,
                                      range: 0.0 ... 1.0,
                                      accent: accent,
                                      format: { parallaxDepthLabel(for: $0) })
                        Toggle("Invert depth", isOn: $settings.zenTiltInvertDepth)
                            .font(.bl(15))
                            .foregroundStyle(BL.paper)
                        Picker("Axes", selection: tiltAxesBinding) {
                            Text("Both").tag(ZenTiltAxes.both)
                            Text("Horizontal").tag(ZenTiltAxes.horizontal)
                            Text("Vertical").tag(ZenTiltAxes.vertical)
                        }
                        .pickerStyle(.menu)
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)
                    }
                } header: {
                    blHeader("Parallax", accent: accent)
                } footer: {
                    Text(settings.zenTiltInvertDepth
                         ? "Tilt for layered depth — darker strokes move more (nearer), brighter less (farther). In Zen, a faint ambient sway keeps the layers drifting at rest."
                         : "Tilt for layered depth — brighter strokes move more (nearer), darker less (farther). In Zen, a faint ambient sway keeps the layers drifting at rest.")
                        .font(.bl(12))
                        .foregroundStyle(BL.muted)
                }
                .listRowBackground(BL.deep)
                #endif

                Section {
                    Picker("Canvas", selection: canvasThemeBinding) {
                        Text("Void").tag(CanvasTheme.void)
                        Text("Paper").tag(CanvasTheme.paper)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                } header: {
                    blHeader("Look", accent: accent)
                } footer: {
                    Text(settings.canvasTheme == .paper
                         ? "Warm parchment with soft ink shadows — a light-theme experiment. Glow adds a colored bloom under the ink."
                         : "Deep black with neon glow. Switch to Paper for ink-on-parchment depth.")
                        .font(.bl(12))
                        .foregroundStyle(BL.muted)
                }
                .listRowBackground(BL.deep)

                if settings.zenMode {
                    Section {
                        Toggle("Show Clock", isOn: $settings.zenShowClock)
                            .font(.bl(15))
                            .foregroundStyle(BL.paper)
                        Toggle("Show Seconds", isOn: $settings.zenShowSeconds)
                            .font(.bl(15))
                            .foregroundStyle(BL.paper)
                            .disabled(!settings.zenShowClock)
                        Toggle("Show Date", isOn: $settings.zenShowDate)
                            .font(.bl(15))
                            .foregroundStyle(BL.paper)
                            .disabled(!settings.zenShowClock)

                        LabeledSlider(title: "Clock Opacity",
                                      value: $settings.zenClockOpacity,
                                      range: 0.4 ... 1.0,
                                      accent: accent,
                                      format: { "\(Int($0 * 100))%" })

                        LabeledSlider(title: "Container",
                                      value: $settings.zenClockContainerOpacity,
                                      range: 0.0 ... 0.5,
                                      accent: accent,
                                      format: { "\(Int($0 * 100))%" })

                        LabeledSlider(title: "Weight",
                                      value: $settings.zenClockFontWeight,
                                      range: 0.1 ... 0.75,
                                      accent: accent,
                                      format: { ZenClockTypography.weightLabel(for: $0) })

                        Picker("Form", selection: clockFormBinding) {
                            Text("Digital").tag(ZenClockForm.digital)
                            Text("Stacked").tag(ZenClockForm.stacked)
                            Text("Editorial").tag(ZenClockForm.editorial)
                        }
                        .pickerStyle(.menu)
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)

                        Picker("Font", selection: clockFontStyleBinding) {
                            Text("System").tag(ZenClockFontStyle.system)
                            Text("Rounded").tag(ZenClockFontStyle.rounded)
                            Text("Monospaced").tag(ZenClockFontStyle.monospaced)
                            Text("Serif").tag(ZenClockFontStyle.serif)
                            Text("Condensed").tag(ZenClockFontStyle.condensed)
                        }
                        .pickerStyle(.menu)
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)

                        Picker("Position", selection: clockPositionBinding) {
                            Text("Top").tag(ZenClockPosition.top)
                            Text("Upper Third").tag(ZenClockPosition.upperThird)
                            Text("Center").tag(ZenClockPosition.center)
                            Text("Lower Third").tag(ZenClockPosition.lowerThird)
                            Text("Top Left").tag(ZenClockPosition.topLeading)
                            Text("Top Right").tag(ZenClockPosition.topTrailing)
                            Text("Bottom Left").tag(ZenClockPosition.bottomLeading)
                            Text("Bottom Right").tag(ZenClockPosition.bottomTrailing)
                        }
                        .pickerStyle(.menu)
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)

                        LabeledSlider(title: "Size",
                                      value: $settings.zenClockSizeScale,
                                      range: 0.5 ... 1.8,
                                      accent: accent,
                                      format: { "\(Int($0 * 100))%" })

                        Toggle("Loop New Patterns", isOn: $settings.zenAutoRegen)
                            .font(.bl(15))
                            .foregroundStyle(BL.paper)
                        if settings.zenAutoRegen {
                            LabeledSlider(title: "Wait",
                                          value: $settings.zenAutoRegenSeconds,
                                          range: 2 ... 30,
                                          step: 1,
                                          accent: accent,
                                          format: { "\(Int($0))s" })
                        }
                    } footer: {
                        Text("Clock, style, and optional looping while the canvas is idle.")
                            .font(.bl(12))
                            .foregroundStyle(BL.muted)
                    }
                    .listRowBackground(BL.deep)
                }

                Section {
                    NavigationLink {
                        PalettePicker(selected: $settings.paletteId)
                    } label: {
                        HStack {
                            Text("Palette")
                                .font(.bl(15))
                                .foregroundStyle(BL.paper)
                            Spacer()
                            LinearGradient(colors: Palette.by(id: settings.paletteId).stops,
                                           startPoint: .leading,
                                           endPoint: .trailing)
                                .frame(width: 96, height: 18)
                                .clipShape(Capsule())
                            Text(Palette.by(id: settings.paletteId).name)
                                .font(.blMono(12))
                                .foregroundStyle(BL.muted)
                        }
                    }
                    Toggle("Glow", isOn: glowToggleBinding)
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)
                    LabeledSlider(title: "Line Width",
                                  value: $settings.lineWidth,
                                  range: 0.5 ... 3.0,
                                  accent: accent,
                                  format: { String(format: "%.1f×", $0) })
                } header: { blHeader("Look", accent: accent) }
                .listRowBackground(BL.deep)

                Section {
                    LabeledSlider(title: "Density",
                                  value: $settings.density,
                                  range: 0.0 ... 1.0,
                                  accent: accent,
                                  format: { densityLabel(for: $0) })
                    Picker("Geometry", selection: $settings.geometryPreset) {
                        Text("Auto").tag("auto")
                        Text("Sparse").tag("sparse")
                        Text("Medium").tag("medium")
                        Text("Dense").tag("dense")
                        Text("Busy").tag("busy")
                    }
                    .pickerStyle(.menu)
                    .font(.bl(15))
                    .foregroundStyle(BL.paper)
                    Toggle("Randomize Palette on New", isOn: $settings.randomizePaletteOnRegenerate)
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)
                } header: { blHeader("Pattern", accent: accent) }
                .listRowBackground(BL.deep)

                Section {
                    LabeledSlider(title: "Speed",
                                  value: $settings.drawSpeed,
                                  range: 0.1 ... 1.0,
                                  accent: accent,
                                  format: { speedLabel(for: $0) })
                } header: { blHeader("Motion", accent: accent) }
                .listRowBackground(BL.deep)

                Section {
                    NavigationLink {
                        WatchSettingsView(settings: settings)
                    } label: {
                        HStack {
                            Image(systemName: "applewatch")
                                .font(.system(size: 17))
                                .foregroundStyle(BL.muted)
                            Text("Apple Watch")
                                .font(.bl(15))
                                .foregroundStyle(BL.paper)
                        }
                    }
                } header: { blHeader("Devices", accent: accent) }
                .listRowBackground(BL.deep)

                if !settings.favorites.isEmpty {
                    Section {
                        NavigationLink("All Favorites") {
                            FavoritesGrid(settings: settings, loadFavorite: loadFavorite)
                        }
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)
                    } header: { blHeader("Favorites · \(settings.favorites.count)", accent: BL.pink) }
                    .listRowBackground(BL.deep)
                }

                Section {
                    if let websiteURL = Self.websiteURL {
                        Link("dr.eamer.dev", destination: websiteURL)
                            .font(.bl(15))
                            .foregroundStyle(BL.paper)
                            .accessibilityLabel("Open dr.eamer.dev")
                            .accessibilityHint("Opens the website in your browser.")
                    }
                }
                .listRowBackground(BL.deep)
            }
            .mandazaScrollContentBackgroundHidden()
            .background(BL.void.ignoresSafeArea())
            .tint(accent)
            .navigationTitle("Settings")
            .toolbarBackground(BL.void, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(accent)
                }
            }
        }
    }

    @ViewBuilder
    private func blHeader(_ label: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            BLDot(color: accent, size: 6)
            BLCaption(label)
        }
        .padding(.top, 4)
    }

    private func speedLabel(for v: Double) -> String {
        switch v {
        case ..<0.3:  return "Calm"
        case ..<0.6:  return "Gentle"
        case ..<0.85: return "Lively"
        default:      return "Rapid"
        }
    }

    private func densityLabel(for v: Double) -> String {
        switch v {
        case ..<0.25: return "Spacious"
        case ..<0.5:  return "Loose"
        case ..<0.75: return "Tight"
        default:      return "Packed"
        }
    }

    private func reactivityLabel(for v: Double) -> String {
        switch v {
        case ..<0.15: return "Subtle"
        case ..<0.5:  return "Minimal"
        case ..<0.8:  return "Lively"
        default:      return "Bold"
        }
    }

    private func parallaxAmountLabel(for v: Double) -> String {
        switch v {
        case ..<0.25: return "Whisper"
        case ..<0.45: return "Subtle"
        case ..<0.7:  return "Present"
        case ..<0.9:  return "Pronounced"
        default:      return "Dramatic"
        }
    }

    private func parallaxDepthLabel(for v: Double) -> String {
        switch v {
        case ..<0.15: return "Flat"
        case ..<0.45: return "Soft"
        case ..<0.75: return "Layered"
        default:      return "Deep"
        }
    }
}

// MARK: - Favorites grid

private struct FavoritesGrid: View {
    @Bindable var settings: MandazaSettings
    let loadFavorite: (MandazaSnapshot) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)],
                      spacing: 12) {
                ForEach(settings.favorites) { snap in
                    Button {
                        loadFavorite(snap)
                        dismiss()
                    } label: {
                        MandazaImageView(snapshot: snap,
                                         size: CGSize(width: 140, height: 220),
                                         scale: 2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(BL.rule, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if WatchSyncController.shared.isPaired,
                           WatchSyncController.shared.isWatchAppInstalled {
                            Button {
                                WatchSyncController.shared.send(snapshot: snap)
                            } label: { Label("Send to Watch", systemImage: "applewatch") }
                        }
                        Button(role: .destructive) {
                            settings.favorites.removeAll { $0.id == snap.id }
                        } label: { Label("Remove", systemImage: "trash") }
                    }
                }
            }
            .padding()
        }
        .mandazaScrollContentBackgroundHidden()
        .background(BL.void.ignoresSafeArea())
        .navigationTitle("Favorites")
        .mandazaNavigationBarTitleDisplayModeInline()
        .toolbarBackground(BL.void, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Reusable slider

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    var accent: Color = BL.cyan
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.bl(15))
                    .foregroundStyle(BL.paper)
                Spacer()
                Text(format(value))
                    .font(.blMono(12))
                    .foregroundStyle(BL.muted)
                    .monospacedDigit()
            }
            #if os(tvOS)
            HStack(spacing: 12) {
                Button {
                    adjustValue(by: -(step ?? (range.upperBound - range.lowerBound) / 20))
                } label: {
                    Image(systemName: "minus")
                }
                .tint(accent)

                Button {
                    adjustValue(by: step ?? (range.upperBound - range.lowerBound) / 20)
                } label: {
                    Image(systemName: "plus")
                }
                .tint(accent)
            }
            #else
            HStack(spacing: 10) {
                Button {
                    adjustValue(by: -(step ?? (range.upperBound - range.lowerBound) / 20))
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(BL.muted)
                .accessibilityLabel("Decrease \(title)")

                if let step {
                    Slider(value: $value, in: range, step: step)
                        .tint(accent)
                } else {
                    Slider(value: $value, in: range)
                        .tint(accent)
                }

                Button {
                    adjustValue(by: step ?? (range.upperBound - range.lowerBound) / 20)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(BL.muted)
                .accessibilityLabel("Increase \(title)")
            }
            .frame(minHeight: 44)
            #endif
        }
        .accessibilityElement(children: .combine)
    }

    private func adjustValue(by delta: Double) {
        value = min(max(value + delta, range.lowerBound), range.upperBound)
    }
}

// MARK: - Palette picker

private struct PalettePicker: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)],
                      spacing: 16) {
                ForEach(Palette.all) { palette in
                    PaletteSwatch(palette: palette,
                                  selected: palette.id == selected) {
                        selected = palette.id
                        dismiss()
                    }
                }
            }
            .padding()
        }
        .mandazaScrollContentBackgroundHidden()
        .background(BL.void.ignoresSafeArea())
        .navigationTitle("Palette")
        .toolbarBackground(BL.void, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct PaletteSwatch: View {
    let palette: Palette
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                LinearGradient(colors: palette.stops,
                               startPoint: .leading,
                               endPoint: .trailing)
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(selected ? BL.accent(for: palette.id) : BL.rule,
                                          lineWidth: selected ? 2 : 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(BL.void, BL.accent(for: palette.id))
                                .padding(6)
                                .shadow(color: BL.accent(for: palette.id).opacity(0.6),
                                        radius: 6)
                        }
                    }
                Text(palette.name)
                    .font(.bl(15, weight: .medium))
                    .foregroundStyle(BL.paper)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(palette.name)\(selected ? ", selected" : "")")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Zen clock

private struct ZenClockOverlay: View {
    let showSeconds: Bool
    let showDate: Bool
    var accent: Color = BL.cyan
    let clockOpacity: Double
    let containerOpacity: Double
    let fontStyle: ZenClockFontStyle
    let fontWeight: Double
    let position: ZenClockPosition
    let form: ZenClockForm
    let sizeScale: Double

    /// Clamp the size slider so an extreme value can never push the clock off
    /// screen or shrink it into illegibility.
    private var scale: CGFloat { CGFloat(min(max(sizeScale, 0.5), 1.8)) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: showSeconds ? 1 : 30)) { ctx in
            let now = ctx.date
            GeometryReader { geo in
                clockContent(now)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background {
                        // Legibility scrim over the mandala, honoring the
                        // persisted container-opacity setting.
                        if containerOpacity > 0.001 {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.black.opacity(min(max(containerOpacity, 0), 0.85)))
                        }
                    }
                    .opacity(min(max(clockOpacity, 0.2), 1.0))
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: ZenClockTypography.alignment(for: position))
                    .padding(.top, topInset(height: geo.size.height))
                    .padding(.bottom, bottomInset(height: geo.size.height))
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(clockAccessibilityLabel(now))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Forms

    @ViewBuilder
    private func clockContent(_ now: Date) -> some View {
        switch form {
        case .digital:   digitalClock(now)
        case .stacked:   stackedClock(now)
        case .editorial: editorialClock(now)
        }
    }

    /// Existing inline treatment: HH:MM (with AM/PM per locale) on one line.
    @ViewBuilder
    private func digitalClock(_ now: Date) -> some View {
        VStack(spacing: 12) {
            Text(inlineTimeString(now))
                .font(clockFont(96))
                .tracking(-2)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(BL.highlight)
                .modifier(ClockShadow(accent: accent))
            dateLine(now)
        }
    }

    /// Hours over minutes, tall and centered — a poster-style block.
    @ViewBuilder
    private func stackedClock(_ now: Date) -> some View {
        VStack(spacing: -12 * scale) {
            Text(hourString(now))
                .font(clockFont(112))
            Text(minuteString(now))
                .font(clockFont(112))
        }
        .tracking(-3)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .foregroundStyle(BL.highlight)
        .modifier(ClockShadow(accent: accent))
        .overlay(alignment: .bottom) {
            if showDate {
                dateLine(now).offset(y: 34 * scale)
            }
        }
    }

    /// Oversized hour with a small stacked minute (and optional date) riding
    /// the baseline — an editorial masthead look.
    @ViewBuilder
    private func editorialClock(_ now: Date) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 10 * scale) {
            Text(hourString(now))
                .font(clockFont(140))
                .tracking(-4)
                .foregroundStyle(BL.highlight)
                .modifier(ClockShadow(accent: accent))
            VStack(alignment: .leading, spacing: 2) {
                Text(minuteString(now))
                    .font(clockFont(46))
                    .foregroundStyle(BL.highlight.opacity(0.92))
                    .modifier(ClockShadow(accent: accent))
                if showDate {
                    Text(now, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(minorFont(15))
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(BL.paper.opacity(0.7))
                        .shadow(color: .black.opacity(0.6), radius: 6)
                }
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.4)
    }

    @ViewBuilder
    private func dateLine(_ now: Date) -> some View {
        if showDate {
            Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(minorFont(14))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(BL.paper.opacity(0.7))
                .shadow(color: .black.opacity(0.7), radius: 6)
        }
    }

    // MARK: Time strings

    private func inlineTimeString(_ date: Date) -> String {
        let style: Date.FormatStyle = showSeconds
            ? .dateTime.hour().minute().second()
            : .dateTime.hour().minute()
        return date.formatted(style)
    }

    private func hourString(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)))
    }

    private func minuteString(_ date: Date) -> String {
        if showSeconds {
            return date.formatted(.dateTime.minute(.twoDigits).second(.twoDigits))
        }
        return date.formatted(.dateTime.minute(.twoDigits))
    }

    private func clockAccessibilityLabel(_ date: Date) -> String {
        var parts = [inlineTimeString(date)]
        if showDate {
            parts.append(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        }
        return parts.joined(separator: ", ")
    }

    // MARK: Fonts & insets

    private func clockFont(_ base: CGFloat) -> Font {
        ZenClockTypography.clockFont(size: base * scale, style: fontStyle, weight: fontWeight)
    }

    private func minorFont(_ base: CGFloat) -> Font {
        ZenClockTypography.clockFont(size: base * scale, style: fontStyle, weight: 0.28)
    }

    private func topInset(height: CGFloat) -> CGFloat {
        switch position {
        case .top, .topLeading, .topTrailing: return 44
        case .upperThird:                      return max(44, height * 0.18)
        case .center, .lowerThird, .bottomLeading, .bottomTrailing: return 0
        }
    }

    private func bottomInset(height: CGFloat) -> CGFloat {
        switch position {
        case .lowerThird, .bottomLeading, .bottomTrailing: return 44
        case .top, .upperThird, .center, .topLeading, .topTrailing: return 0
        }
    }
}

/// Always-on two-layer shadow: a dark drop for legibility over the mandala,
/// plus a subtle phylum-accent bloom.
private struct ClockShadow: ViewModifier {
    let accent: Color
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.7), radius: 16)
            .shadow(color: accent.opacity(0.3), radius: 28)
    }
}

// MARK: - Toast

private struct Toast: View {
    let text: String
    var accent: Color = BL.green

    var body: some View {
        HStack(spacing: 10) {
            BLDot(color: accent, size: 6)
            Text(text)
                .font(.bl(13, weight: .regular))
                .tracking(0.2)
                .foregroundStyle(BL.highlight)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
            Capsule()
                .fill(BL.deep.opacity(0.85))
                .overlay(Capsule().strokeBorder(BL.rule, lineWidth: 1))
        }
        .accessibilityAddTraits(.isStaticText)
    }
}

private extension View {
    @ViewBuilder
    func mandazaScrollContentBackgroundHidden() -> some View {
        #if os(tvOS)
        self
        #else
        self.scrollContentBackground(.hidden)
        #endif
    }

    @ViewBuilder
    func mandazaNavigationBarTitleDisplayModeInline() -> some View {
        #if os(tvOS)
        self
        #else
        self.navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Applies tilt as a UIKit `CGAffineTransform` so motion samples never
/// invalidate SwiftUI bodies (which was freezing the canvas TimelineView).
private struct ParallaxHost<Content: View>: UIViewControllerRepresentable {
    var provider: TiltProvider
    var multiplier: CGFloat = 1
    var content: Content

    init(provider: TiltProvider,
         multiplier: CGFloat = 1,
         @ViewBuilder content: () -> Content) {
        self.provider = provider
        self.multiplier = multiplier
        self.content = content()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []
        context.coordinator.bind(provider: provider, view: host.view, multiplier: multiplier)
        return host
    }

    func updateUIViewController(_ host: UIHostingController<Content>, context: Context) {
        host.rootView = content
        context.coordinator.bind(provider: provider, view: host.view, multiplier: multiplier)
    }

    static func dismantleUIViewController(_ host: UIHostingController<Content>,
                                          coordinator: Coordinator) {
        coordinator.unbind()
    }

    @MainActor
    final class Coordinator {
        private var listenerID: UUID?
        private weak var provider: TiltProvider?
        private weak var view: UIView?
        private var multiplier: CGFloat = 1

        func bind(provider: TiltProvider, view: UIView, multiplier: CGFloat) {
            self.multiplier = multiplier
            self.view = view
            if listenerID == nil || self.provider !== provider {
                unbind()
                self.provider = provider
                listenerID = provider.addListener { [weak self] offset in
                    self?.apply(offset)
                }
            } else {
                apply(provider.offset)
            }
        }

        func unbind() {
            if let listenerID, let provider {
                provider.removeListener(listenerID)
            }
            listenerID = nil
            provider = nil
            view?.transform = .identity
            view = nil
        }

        private func apply(_ offset: CGSize) {
            view?.transform = CGAffineTransform(
                translationX: offset.width * multiplier,
                y: offset.height * multiplier)
        }
    }
}

#Preview { ContentView() }
#endif
