import SwiftUI
import UIKit
import WidgetKit

struct ContentView: View {

    // Shared, App Group-backed settings (single source of truth for app + widgets).
    @State private var settings = MandazaSettings.shared

    // Ephemeral state — purely view-local.
    @State private var seed = UUID().uuidString
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

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    // MARK: - Body

    var body: some View {
        ZStack {
            // Layer 1 — edge-to-edge canvas.
            GeometryReader { geo in
                ZStack {
                    Color.black
                    MandazaCanvas(size: geo.size,
                                  seed: UUID(uuidString: seed) ?? UUID(),
                                  paletteId: settings.paletteId,
                                  config: settings.engineConfig(),
                                  onIdleChange: handleIdleChange(_:))
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, new in canvasSize = new }
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mandaza canvas")
            .accessibilityHint(canvasA11yHint)
            .accessibilityAddTraits(canvasA11yTraits)

            // Layer 2 — clock overlay (tinted by current palette's phylum accent).
            if settings.zenMode, settings.zenShowClock {
                ZenClockOverlay(showSeconds: settings.zenShowSeconds,
                                showDate: settings.zenShowDate,
                                accent: BL.accent(for: settings.paletteId))
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
            .animation(.easeInOut(duration: 0.45), value: controlsFaded)
            .animation(.easeInOut(duration: 0.25), value: showRecents)

            if controlsFaded {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        restoreControls()
                    }
                    .accessibilityLabel("Show controls")
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
                          loadFavorite: loadFavorite(_:))
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
        .onChange(of: showSettings) { _, isPresented in
            if !isPresented { noteInteraction() }
        }
        .onChange(of: exportInProgress) { _, inProgress in
            if !inProgress { noteInteraction() }
        }
        .onOpenURL { handleIncomingURL($0) }
        .onAppear { scheduleControlsFade() }
        .onDisappear { controlsFadeTask?.cancel() }
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
        !UIAccessibility.isVoiceOverRunning && !UIAccessibility.isSwitchControlRunning
    }

    // MARK: - Control bar

    private var controlBar: some View {
        let accent = BL.accent(for: settings.paletteId)
        return HStack(alignment: .center, spacing: 10) {
            dockButton(system: recents.isEmpty ? "clock" : "clock.arrow.circlepath",
                       label: "Previous",
                       accent: accent,
                       enabled: !recents.isEmpty) {
                noteInteraction()
                toggleRecents()
            }

            dockButton(system: "slider.horizontal.3",
                       label: "Tune",
                       accent: accent) {
                noteInteraction()
                showSettings = true
            }

            Button {
                noteInteraction()
                regenerate()
            } label: {
                newPatternButton(accent: accent)
            }
            .accessibilityLabel("New pattern")
            .accessibilityHint("Generates a new Mandaza and keeps the current one in Previous.")
            .buttonStyle(.plain)

            dockButton(system: favoriteIcon,
                       label: settings.isFavorite(seed: seed) ? "Saved" : "Favorite",
                       accent: settings.isFavorite(seed: seed) ? BL.pink : accent) {
                noteInteraction()
                toggleFavorite()
            }

            Menu {
                Button("Save Screen Size") {
                    noteInteraction()
                    exportFullScreen()
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
                        .frame(width: 32, height: 28)
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

    private func newPatternButton(accent: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accent)
                .frame(height: 28)
                .shadow(color: accent.opacity(0.55), radius: 10)
            Text("New")
                .font(.blMono(10, weight: .semibold))
                .foregroundStyle(BL.highlight)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(alignment: .top) {
            Capsule()
                .fill(accent.opacity(0.10))
                .overlay(Capsule().strokeBorder(accent.opacity(0.35), lineWidth: 1))
                .frame(height: 50)
        }
        .contentShape(Rectangle())
    }

    private var favoriteIcon: String {
        settings.isFavorite(seed: seed) ? "heart.fill" : "heart"
    }

    private func toggleRecents() {
        guard !recents.isEmpty else { return }
        showRecents.toggle()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Canvas gestures

    /// A canvas tap is the primary cycle gesture while controls are visible.
    /// Once the shelf has faded, the transparent tap catcher above handles
    /// the first tap so the artwork is not accidentally replaced.
    private func canvasTapped() {
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
        guard longPressEnabled else { return }
        noteInteraction()
        regenerate()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
        controlsFadeTask = Task { @MainActor in
            try? await Task.sleep(for: controlsFadeDelay)
            guard !Task.isCancelled, !showSettings, exportAlert == nil, !exportInProgress else { return }
            showRecents = false
            controlsFaded = true
        }
    }

    private func regenerate() {
        // Push the current snapshot into the Recents ring buffer BEFORE the
        // seed changes — so the artwork the user is about to overwrite is
        // recoverable.
        pushCurrentToRecents()
        seed = UUID().uuidString
        settings.paletteId = Palette.all.filter { $0.id != settings.paletteId }
            .randomElement()?.id ?? settings.paletteId
        UISelectionFeedbackGenerator().selectionChanged()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Recents ring buffer

    private func pushCurrentToRecents() {
        let snap = MandazaSnapshot(seed: seed,
                                   paletteId: settings.paletteId,
                                   config: settings.engineConfig())
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
        showRecents = false
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Favorites

    private func toggleFavorite() {
        let now = settings.toggleFavorite(seed: seed,
                                          paletteId: settings.paletteId,
                                          config: settings.engineConfig())
        showToast(now ? "Saved to Favorites" : "Removed from Favorites")
        WidgetCenter.shared.reloadAllTimelines()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func loadFavorite(_ snapshot: MandazaSnapshot) {
        seed = snapshot.seed
        settings.paletteId = snapshot.paletteId
    }

    // MARK: - Zen / scenePhase

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
            if lastIdle, settings.zenMode, settings.zenAutoRegen, !reduceMotion {
                handleIdleChange(true)
            }
        case .background, .inactive:
            autoRegenTask?.cancel()
        @unknown default:
            break
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "mandaza" else { return }
        // mandaza://seed/<UUID>
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.host == "seed", let uuidString = parts.first {
            seed = uuidString
        }
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
        let cfg = settings.engineConfig()

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
    @Bindable var settings: MandazaSettings
    let loadFavorite: (MandazaSnapshot) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let accent = BL.accent(for: settings.paletteId)
        return NavigationStack {
            Form {
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
                    Toggle("Glow", isOn: $settings.glow)
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
                    Toggle("Zen Mode", isOn: $settings.zenMode.animation())
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)
                } header: {
                    blHeader("Zen Mode", accent: accent)
                } footer: {
                    Text("Show a clock over the mandala and loop new patterns continuously.")
                        .font(.bl(12))
                        .foregroundStyle(BL.muted)
                }
                .listRowBackground(BL.deep)

                if settings.zenMode {
                    Section {
                        Toggle("Show Clock", isOn: $settings.zenShowClock)
                        Toggle("Show Seconds", isOn: $settings.zenShowSeconds)
                            .disabled(!settings.zenShowClock)
                        Toggle("Show Date", isOn: $settings.zenShowDate)
                            .disabled(!settings.zenShowClock)
                    } header: { blHeader("Clock", accent: accent) }
                    .listRowBackground(BL.deep)
                    .font(.bl(15))
                    .foregroundStyle(BL.paper)

                    Section {
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
                    } header: { blHeader("Auto-Regenerate", accent: accent) }
                    .listRowBackground(BL.deep)
                }

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
                    NavigationLink("About Mandaza") { AboutScreen() }
                        .font(.bl(15))
                        .foregroundStyle(BL.paper)
                }
                .listRowBackground(BL.deep)
            }
            .scrollContentBackground(.hidden)
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
                        Button(role: .destructive) {
                            settings.favorites.removeAll { $0.id == snap.id }
                        } label: { Label("Remove", systemImage: "trash") }
                    }
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(BL.void.ignoresSafeArea())
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BL.void, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - About / attribution

private struct AboutScreen: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        BLDot(color: BL.cyan, size: 8)
                        BLCaption("mandaza · v\(version)", tint: BL.muted)
                    }
                    Text("small luminous things,\nmapped where they were found.")
                        .font(.system(size: 36, weight: .light, design: .default))
                        .tracking(-0.5)
                        .lineSpacing(2)
                        .foregroundStyle(BL.highlight)
                }

                section(label: "attribution", accent: BL.cyan) {
                    Text("The hexagonal-loop algorithm is adapted from Charlotte Dann's *Hexagonal Generative Art* CodePen, building on David Siaw's Hexlife. Truchet tile mathematics is public domain (Sébastien Truchet, 1704).")
                        .font(.bl(14))
                        .lineSpacing(4)
                        .foregroundStyle(BL.paper)
                    Link("Charlotte Dann — original CodePen",
                         destination: URL(string: "https://codepen.io/pouretrebelle/pen/ZBNJmd")!)
                        .font(.bl(13)).tint(BL.cyan)
                    Link("Hexagonal Generative Art — write-up",
                         destination: URL(string: "https://codepen.io/pouretrebelle/post/hexagons")!)
                        .font(.bl(13)).tint(BL.cyan)
                }

                section(label: "privacy", accent: BL.green) {
                    Text("Mandaza collects no data. No analytics, no network requests, no account. The only system permission requested is one-time write access to Photos when you tap Save.")
                        .font(.bl(14))
                        .lineSpacing(4)
                        .foregroundStyle(BL.paper)
                }

                section(label: "feedback", accent: BL.violet) {
                    Link("Email the developer",
                         destination: URL(string: "mailto:luke@lukesteuber.com?subject=Mandaza%20feedback")!)
                        .font(.bl(13)).tint(BL.violet)
                }

                HStack {
                    BLCaption("built by luke steuber", tint: BL.muted)
                    Spacer()
                    BLCaption("2026", tint: BL.muted)
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(BL.void.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(BL.deep, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    @ViewBuilder
    private func section<Content: View>(
        label: String, accent: Color, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                BLDot(color: accent, size: 6)
                BLCaption(label, tint: accent.opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 8) { content() }
                .padding(.leading, 2)
        }
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
            if let step {
                Slider(value: $value, in: range, step: step)
                    .tint(accent)
            } else {
                Slider(value: $value, in: range)
                    .tint(accent)
            }
        }
        .accessibilityElement(children: .combine)
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
        .scrollContentBackground(.hidden)
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

    var body: some View {
        TimelineView(.periodic(from: .now, by: showSeconds ? 1 : 30)) { ctx in
            let now = ctx.date
            VStack(spacing: 12) {
                Text(timeString(now))
                    .font(.system(size: 96, weight: .ultraLight, design: .default))
                    .tracking(-2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(BL.highlight)
                    // Two-layer shadow: dark drop for legibility over the
                    // mandala, plus a subtle phylum bloom.
                    .shadow(color: .black.opacity(0.7), radius: 16)
                    .shadow(color: accent.opacity(0.3), radius: 28)
                if showDate {
                    Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.bl(14, weight: .light))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(BL.paper.opacity(0.7))
                        .shadow(color: .black.opacity(0.7), radius: 6)
                }
            }
            .padding(.horizontal, 32)
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

#Preview { ContentView() }
