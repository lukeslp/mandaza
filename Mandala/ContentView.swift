import SwiftUI
import UIKit
import WidgetKit

struct ContentView: View {

    // Shared, App Group-backed settings (single source of truth for app + widgets).
    @State private var settings = MandalaSettings.shared

    // Ephemeral state — purely view-local.
    @State private var seed = UUID().uuidString
    @State private var canvasSize: CGSize = .zero
    @State private var showSettings = false
    @State private var exportInProgress = false
    @State private var exportAlert: ExportAlert? = nil
    @State private var toastMessage: String? = nil
    @State private var toastClearTask: Task<Void, Never>? = nil
    /// Controls are never fully hidden — they fade between bright (1.0) and an
    /// ambient baseline (~0.18) so the bar always remains discoverable. Triggered
    /// by every tap; auto-dims after 1.5s with a gentle 0.8s easeInOut.
    @State private var controlsBright = true
    @State private var dimControlsTask: Task<Void, Never>? = nil
    @State private var autoRegenTask: Task<Void, Never>? = nil
    @State private var lastIdle: Bool = false

    private let dwellSeconds: TimeInterval = 1.5
    private let fadeSeconds: Double = 0.8
    /// Baseline opacity when controls are at rest. Soft enough to recede,
    /// strong enough to remain discoverable. Modeled on BL.muted (0.55).
    private let ambientOpacity: Double = 0.35

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
                    MandalaCanvas(size: geo.size,
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
            .onTapGesture { canvasTapped() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mandala canvas")
            .accessibilityHint("Double tap to generate a new pattern")
            .accessibilityAddTraits(.isButton)

            // Layer 2 — clock overlay (tinted by current palette's phylum accent).
            if settings.zenMode, settings.zenShowClock {
                ZenClockOverlay(showSeconds: settings.zenShowSeconds,
                                showDate: settings.zenShowDate,
                                accent: BL.accent(for: settings.paletteId))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Layer 3 — ambient control bar. Always present; opacity breathes.
            VStack {
                Spacer()
                controlBar
                    .opacity(controlsBright ? 1.0 : ambientOpacity)
                    .animation(.easeInOut(duration: fadeSeconds), value: controlsBright)
            }

            // Layer 4 — export progress dim.
            if exportInProgress {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("Saving…")
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .safeAreaInset(edge: .top) {
            if let message = toastMessage {
                Toast(text: message, accent: BL.accent(for: settings.paletteId))
                    .padding(.top, 4)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: brightenControls) {
            SettingsSheet(settings: settings,
                          loadFavorite: loadFavorite(_:))
        }
        .alert(item: $exportAlert) { alert in
            switch alert.kind {
            case .permissionDenied:
                return Alert(
                    title: Text("Photos Access Needed"),
                    message: Text("Mandala needs permission to add this image to your Photo Library."),
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
        .onAppear { scheduleDimControls() }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .onOpenURL { handleIncomingURL($0) }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        let accent = BL.accent(for: settings.paletteId)
        return HStack(spacing: 20) {
            controlButton(system: "arrow.triangle.2.circlepath", label: "Regenerate", glow: accent) {
                regenerate()
            }
            controlButton(system: favoriteIcon, label: "Favorite",
                          glow: settings.isFavorite(seed: seed) ? BL.pink : accent) {
                toggleFavorite()
            }
            controlButton(system: "slider.horizontal.3", label: "Settings", glow: accent) {
                showSettings = true
            }
            controlButton(system: "square.and.arrow.down.fill", label: "Save", glow: accent,
                          enabled: !exportInProgress) {
                exportFullScreen()
            }
            Menu {
                ForEach(ExportService.presets, id: \.label) { preset in
                    Button("\(preset.label)  •  \(Int(preset.size.width))×\(Int(preset.size.height))") {
                        exportAt(size: preset.size)
                    }
                }
            } label: {
                controlIcon(system: "rectangle.portrait.and.arrow.right.fill", glow: accent)
                    .opacity(exportInProgress ? 0.4 : 1)
            }
            .accessibilityLabel("Export resolution")
            .disabled(exportInProgress)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background {
            Capsule()
                .fill(BL.deep.opacity(0.7))
                .overlay(Capsule().strokeBorder(BL.rule, lineWidth: 1))
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.bottom, 28)
    }

    private func controlButton(system: String,
                               label: String,
                               glow: Color,
                               enabled: Bool = true,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            controlIcon(system: system, glow: glow)
                .opacity(enabled ? 1 : 0.35)
        }
        .accessibilityLabel(label)
        .disabled(!enabled)
    }

    private func controlIcon(system: String, glow: Color) -> some View {
        Image(systemName: system)
            .font(.system(size: 19, weight: .light))
            .foregroundStyle(BL.highlight)
            .shadow(color: controlsBright ? glow.opacity(0.55) : .clear, radius: 8)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    private var favoriteIcon: String {
        settings.isFavorite(seed: seed) ? "heart.fill" : "heart"
    }

    // MARK: - Tap + reveal

    private func canvasTapped() {
        regenerate()
        brightenControls()
    }

    private func regenerate() {
        seed = UUID().uuidString
        settings.paletteId = Palette.all.filter { $0.id != settings.paletteId }
            .randomElement()?.id ?? settings.paletteId
        UISelectionFeedbackGenerator().selectionChanged()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Bring controls back to full brightness, then schedule the gentle dim.
    private func brightenControls() {
        controlsBright = true
        scheduleDimControls()
    }

    private func scheduleDimControls() {
        dimControlsTask?.cancel()
        dimControlsTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(dwellSeconds))
            if !Task.isCancelled { controlsBright = false }
        }
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

    private func loadFavorite(_ snapshot: MandalaSnapshot) {
        seed = snapshot.seed
        settings.paletteId = snapshot.paletteId
        brightenControls()
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
        guard url.scheme == "mandala" else { return }
        // mandala://seed/<UUID>
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.host == "seed", let uuidString = parts.first {
            seed = uuidString
            brightenControls()
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
            let image = MandalaEngine.renderImage(seed: s,
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
    @Bindable var settings: MandalaSettings
    let loadFavorite: (MandalaSnapshot) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Look") {
                    NavigationLink {
                        PalettePicker(selected: $settings.paletteId)
                    } label: {
                        HStack {
                            Text("Palette")
                            Spacer()
                            LinearGradient(colors: Palette.by(id: settings.paletteId).stops,
                                           startPoint: .leading,
                                           endPoint: .trailing)
                                .frame(width: 96, height: 18)
                                .clipShape(Capsule())
                            Text(Palette.by(id: settings.paletteId).name)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Glow", isOn: $settings.glow)
                    LabeledSlider(title: "Line Width",
                                  value: $settings.lineWidth,
                                  range: 0.5 ... 3.0,
                                  format: { String(format: "%.1f×", $0) })
                }

                Section("Pattern") {
                    LabeledSlider(title: "Density",
                                  value: $settings.density,
                                  range: 0.0 ... 1.0,
                                  format: { densityLabel(for: $0) })
                    Picker("Geometry", selection: $settings.geometryPreset) {
                        Text("Auto").tag("auto")
                        Text("Sparse").tag("sparse")
                        Text("Medium").tag("medium")
                        Text("Dense").tag("dense")
                        Text("Busy").tag("busy")
                    }
                    .pickerStyle(.menu)
                }

                Section("Motion") {
                    LabeledSlider(title: "Speed",
                                  value: $settings.drawSpeed,
                                  range: 0.1 ... 1.0,
                                  format: { speedLabel(for: $0) })
                }

                Section {
                    Toggle("Zen Mode", isOn: $settings.zenMode.animation())
                } footer: {
                    Text("Show a clock over the mandala and loop new patterns continuously.")
                }

                if settings.zenMode {
                    Section("Clock") {
                        Toggle("Show Clock", isOn: $settings.zenShowClock)
                        Toggle("Show Seconds", isOn: $settings.zenShowSeconds)
                            .disabled(!settings.zenShowClock)
                        Toggle("Show Date", isOn: $settings.zenShowDate)
                            .disabled(!settings.zenShowClock)
                    }

                    Section("Auto-Regenerate") {
                        Toggle("Loop New Patterns", isOn: $settings.zenAutoRegen)
                        if settings.zenAutoRegen {
                            LabeledSlider(title: "Wait",
                                          value: $settings.zenAutoRegenSeconds,
                                          range: 2 ... 30,
                                          step: 1,
                                          format: { "\(Int($0))s" })
                        }
                    }
                }

                if !settings.favorites.isEmpty {
                    Section("Favorites (\(settings.favorites.count))") {
                        NavigationLink("All Favorites") {
                            FavoritesGrid(settings: settings, loadFavorite: loadFavorite)
                        }
                    }
                }

                Section {
                    NavigationLink("About Mandala") { AboutScreen() }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
    @Bindable var settings: MandalaSettings
    let loadFavorite: (MandalaSnapshot) -> Void
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
                        MandalaImageView(snapshot: snap,
                                         size: CGSize(width: 140, height: 220),
                                         scale: 2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
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
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
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
                        BLCaption("mandala · v\(version)", tint: BL.muted)
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
                    Text("Mandala collects no data. No analytics, no network requests, no account. The only system permission requested is one-time write access to Photos when you tap Save.")
                        .font(.bl(14))
                        .lineSpacing(4)
                        .foregroundStyle(BL.paper)
                }

                section(label: "feedback", accent: BL.violet) {
                    Link("Email the developer",
                         destination: URL(string: "mailto:luke@lukesteuber.com?subject=Mandala%20feedback")!)
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
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
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
        .navigationTitle("Palette")
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
                            .strokeBorder(selected ? Color.accentColor : Color.white.opacity(0.1),
                                          lineWidth: selected ? 3 : 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(6)
                                .shadow(radius: 2)
                        }
                    }
                Text(palette.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
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
