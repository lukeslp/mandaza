import SwiftUI
import UIKit

struct ContentView: View {

    // MARK: - Persisted settings

    @AppStorage("paletteId")     private var paletteId: String  = Palette.all.first?.id ?? "aurora"
    @AppStorage("drawSpeed")     private var drawSpeed: Double  = 0.707
    @AppStorage("lineWidth")     private var lineWidth: Double  = 1.2
    @AppStorage("glow")          private var glow: Bool         = true

    @AppStorage("zenMode")             private var zenMode: Bool         = false
    @AppStorage("zenShowClock")        private var zenShowClock: Bool    = true
    @AppStorage("zenShowSeconds")      private var zenShowSeconds: Bool  = false
    @AppStorage("zenShowDate")         private var zenShowDate: Bool     = true
    @AppStorage("zenAutoRegenerate")   private var zenAutoRegen: Bool    = true
    @AppStorage("zenAutoRegenSeconds") private var zenAutoRegenSeconds: Double = 6

    // MARK: - Ephemeral state

    @State private var seed = UUID()
    @State private var canvasSize: CGSize = .zero
    @State private var displayScale: CGFloat = 3   // updated from environment
    @State private var showSettings = false
    @State private var exportInProgress = false
    @State private var exportAlert: ExportAlert? = nil
    @State private var toastMessage: String? = nil
    @State private var toastClearTask: Task<Void, Never>? = nil
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>? = nil
    @State private var autoRegenTask: Task<Void, Never>? = nil
    @State private var lastIdle: Bool = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var envDisplayScale

    private var engineConfig: EngineConfig {
        var c = EngineConfig()
        c.drawSpeed = drawSpeed
        c.lineWidth = lineWidth
        c.glow = glow
        return c
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Layer 1 — edge-to-edge canvas. Inner GeometryReader ignores safe
            // area so `geo.size` matches the frame the engine renders into.
            GeometryReader { geo in
                ZStack {
                    Color.black
                    MandalaCanvas(size: geo.size,
                                  seed: seed,
                                  paletteId: paletteId,
                                  config: engineConfig,
                                  onIdleChange: handleIdleChange(_:))
                }
                .onAppear {
                    canvasSize = geo.size
                    displayScale = envDisplayScale
                }
                .onChange(of: geo.size) { _, new in canvasSize = new }
                .onChange(of: envDisplayScale) { _, new in displayScale = new }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { canvasTapped() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mandala canvas")
            .accessibilityHint("Double tap to generate a new pattern")
            .accessibilityAddTraits(.isButton)

            // Layer 2 — clock overlay, centered within safe area.
            if zenMode, zenShowClock {
                ZenClockOverlay(showSeconds: zenShowSeconds,
                                showDate: zenShowDate)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Layer 3 — floating control bar.
            VStack {
                Spacer()
                if controlsVisible {
                    controlBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: controlsVisible)

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
                Toast(text: message)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: { revealControls() }) {
            SettingsSheet(paletteId: $paletteId,
                          drawSpeed: $drawSpeed,
                          lineWidth: $lineWidth,
                          glow: $glow,
                          zenMode: $zenMode,
                          zenShowClock: $zenShowClock,
                          zenShowSeconds: $zenShowSeconds,
                          zenShowDate: $zenShowDate,
                          zenAutoRegen: $zenAutoRegen,
                          zenAutoRegenSeconds: $zenAutoRegenSeconds)
        }
        .alert(item: $exportAlert) { alert in
            switch alert.kind {
            case .permissionDenied:
                return Alert(
                    title: Text("Photos Access Needed"),
                    message: Text("Mandala needs permission to add this image to your Photo Library."),
                    primaryButton: .default(Text("Open Settings"), action: openAppSettings),
                    secondaryButton: .cancel()
                )
            case .renderFailed:
                return Alert(
                    title: Text("Couldn't Save"),
                    message: Text("The image couldn't be rendered. Try a smaller resolution."),
                    primaryButton: .default(Text("Try Smaller"), action: { exportFallback() }),
                    secondaryButton: .cancel()
                )
            case .saveFailed(let message):
                return Alert(
                    title: Text("Couldn't Save"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear { scheduleHideControls() }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 24) {
            controlButton(system: "arrow.triangle.2.circlepath", label: "Regenerate") {
                regenerate()
            }
            controlButton(system: "slider.horizontal.3", label: "Settings") {
                showSettings = true
            }
            Button {
                exportFullScreen()
            } label: {
                controlIcon(system: "square.and.arrow.down.fill")
            }
            .accessibilityLabel("Save")
            .disabled(exportInProgress)
            .opacity(exportInProgress ? 0.4 : 1)

            Menu {
                ForEach(ExportService.presets, id: \.label) { preset in
                    Button("\(preset.label)  •  \(Int(preset.size.width))×\(Int(preset.size.height))") {
                        exportAt(size: preset.size)
                    }
                }
            } label: {
                controlIcon(system: "rectangle.portrait.and.arrow.right.fill")
                    .opacity(exportInProgress ? 0.4 : 1)
            }
            .accessibilityLabel("Export resolution")
            .disabled(exportInProgress)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 28)
    }

    private func controlButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            controlIcon(system: system)
        }
        .accessibilityLabel(label)
    }

    private func controlIcon(system: String) -> some View {
        Image(systemName: system)
            .font(.title2.weight(.medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    // MARK: - Tap + reveal

    private func canvasTapped() {
        regenerate()
        revealControls()
    }

    private func regenerate() {
        seed = UUID()
        paletteId = Palette.all.filter { $0.id != paletteId }.randomElement()?.id ?? paletteId
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func revealControls() {
        controlsVisible = true
        scheduleHideControls()
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { controlsVisible = false }
        }
    }

    // MARK: - Auto-regenerate (zen mode)

    private func handleIdleChange(_ idle: Bool) {
        lastIdle = idle
        autoRegenTask?.cancel()
        guard idle, zenMode, zenAutoRegen, !reduceMotion else { return }
        let wait = zenAutoRegenSeconds
        autoRegenTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            if !Task.isCancelled { regenerate() }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // Resuming: re-arm auto-regen if we're sitting idle in Zen mode.
            if lastIdle, zenMode, zenAutoRegen, !reduceMotion {
                handleIdleChange(true)
            }
        case .background, .inactive:
            autoRegenTask?.cancel()
        @unknown default:
            break
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
        // Step down to the next-smaller preset.
        let presets = ExportService.presets
        let smallest = presets.last { $0.size.width <= 1290 }?.size
            ?? CGSize(width: 1170, height: 2532)
        exportAt(size: smallest)
    }

    private func exportAt(size: CGSize) {
        guard !exportInProgress else { return }
        exportInProgress = true
        let s = seed.uuidString
        let pid = paletteId
        let cfg = engineConfig

        Task.detached(priority: .userInitiated) {
            let image = MandalaEngine.renderImage(seed: s,
                                                  paletteId: pid,
                                                  config: cfg,
                                                  size: size)
            await MainActor.run {
                handleRenderedImage(image)
            }
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
    @Binding var paletteId: String
    @Binding var drawSpeed: Double
    @Binding var lineWidth: Double
    @Binding var glow: Bool
    @Binding var zenMode: Bool
    @Binding var zenShowClock: Bool
    @Binding var zenShowSeconds: Bool
    @Binding var zenShowDate: Bool
    @Binding var zenAutoRegen: Bool
    @Binding var zenAutoRegenSeconds: Double

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Look") {
                    NavigationLink {
                        PalettePicker(selected: $paletteId)
                    } label: {
                        HStack {
                            Text("Palette")
                            Spacer()
                            LinearGradient(colors: Palette.by(id: paletteId).stops,
                                           startPoint: .leading,
                                           endPoint: .trailing)
                                .frame(width: 96, height: 18)
                                .clipShape(Capsule())
                            Text(Palette.by(id: paletteId).name)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Glow", isOn: $glow)
                    LabeledSlider(title: "Line Width",
                                  value: $lineWidth,
                                  range: 0.5 ... 3.0,
                                  format: { String(format: "%.1f×", $0) })
                }

                Section("Motion") {
                    LabeledSlider(title: "Speed",
                                  value: $drawSpeed,
                                  range: 0.1 ... 1.0,
                                  format: { speedLabel(for: $0) })
                }

                Section {
                    Toggle("Zen Mode", isOn: $zenMode.animation())
                } footer: {
                    Text("Show a clock over the mandala and loop new patterns continuously.")
                }

                if zenMode {
                    Section("Clock") {
                        Toggle("Show Clock", isOn: $zenShowClock)
                        Toggle("Show Seconds", isOn: $zenShowSeconds)
                            .disabled(!zenShowClock)
                        Toggle("Show Date", isOn: $zenShowDate)
                            .disabled(!zenShowClock)
                    }

                    Section("Auto-Regenerate") {
                        Toggle("Loop New Patterns", isOn: $zenAutoRegen)
                        if zenAutoRegen {
                            LabeledSlider(title: "Wait",
                                          value: $zenAutoRegenSeconds,
                                          range: 2 ... 30,
                                          step: 1,
                                          format: { "\(Int($0))s" })
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
}

// MARK: - About / attribution

private struct AboutScreen: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mandala")
                        .font(.title.weight(.semibold))
                    Text("Version \(version)")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Attribution") {
                Text("The hexagonal-loop algorithm is adapted from Charlotte Dann's *Hexagonal Generative Art* CodePen, building on David Siaw's Hexlife. Truchet tile mathematics is public domain (Sébastien Truchet, 1704).")
                    .font(.callout)
                Link("Charlotte Dann — original CodePen",
                     destination: URL(string: "https://codepen.io/pouretrebelle/pen/ZBNJmd")!)
                Link("Hexagonal Generative Art — write-up",
                     destination: URL(string: "https://codepen.io/pouretrebelle/post/hexagons")!)
            }

            Section("Privacy") {
                Text("Mandala collects no data. No analytics, no network requests, no account. The only system permission requested is one-time write access to Photos when you tap Save.")
                    .font(.callout)
            }

            Section("Feedback") {
                Link("Email the developer",
                     destination: URL(string: "mailto:luke@lukesteuber.com?subject=Mandala%20feedback")!)
            }

            Section {
                Text("Built by Luke Steuber.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reusable slider with descriptive value label

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

    var body: some View {
        TimelineView(.periodic(from: .now, by: showSeconds ? 1 : 30)) { ctx in
            let now = ctx.date
            VStack(spacing: 8) {
                Text(timeString(now))
                    .font(.system(size: 96, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.75), radius: 18)
                if showDate {
                    Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.title3.weight(.light))
                        .foregroundStyle(.white.opacity(0.75))
                        .shadow(color: .black.opacity(0.75), radius: 8)
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

    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(.white)
            .accessibilityAddTraits(.isStaticText)
    }
}

#Preview { ContentView() }
