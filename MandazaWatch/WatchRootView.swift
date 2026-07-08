import SwiftUI
import WatchKit

/// The watch face: a full-screen live mandala.
///
/// - Tap to regenerate a new pattern (clears any design pinned from iPhone).
/// - Digital Crown cycles the palette.
/// - Long-press opens a small settings sheet (Music Mode, sync status).
/// - After a pattern finishes drawing it pauses, then auto-redesigns.
/// - Engine settings are synced from the iPhone over WatchConnectivity;
///   built-in defaults apply until the first sync arrives.
/// - The iPhone can push a specific design ("Send to Watch"); it stays
///   pinned across launches until the user taps for a fresh pattern.
///
/// Sizing: the canvas is framed to `WKInterfaceDevice.screenBounds` so the
/// engine is laid out for the exact watch screen (rather than a GeometryReader
/// size that can disagree with the rendered Canvas and squash the pattern into
/// a portrait strip). Battery: throttled cadence while active, frozen when the
/// wrist drops / the app backgrounds; MandazaCanvas also pauses under Always-On.
/// Music Mode raises the cadence slightly and taps the microphone — both stop
/// the moment the app deactivates or the wrist drops.
struct WatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    @State private var settings = MandazaSettings.shared
    @State private var seed = UUID()
    @State private var paletteIndex = 0
    @State private var crown = 0.0
    @State private var regenTask: Task<Void, Never>?

    @State private var reactor = AudioReactor()
    @State private var showSheet = false
    @State private var showFromPhone = false
    @State private var fromPhoneTask: Task<Void, Never>?
    /// Last successful settings sync from the iPhone (epoch seconds; 0 = never).
    @AppStorage("watch.lastSyncAt") private var lastSyncAt: Double = 0

    private var screenSize: CGSize {
        WKInterfaceDevice.current().screenBounds.size
    }

    private var paletteId: String {
        guard !Palette.all.isEmpty else { return "aurora" }
        let count = Palette.all.count
        let id = Palette.all[((paletteIndex % count) + count) % count].id
        return MandazaScreenshot.palette(id)
    }

    private var cadence: MandazaCadence {
        guard scenePhase == .active else { return .paused }
        return .interval(reactor.source.isActive ? 1.0 / 24.0 : 1.0 / 18.0)
    }

    private var musicModeBinding: Binding<Bool> {
        Binding(
            get: { reactor.source.isActive },
            set: { on in
                if on {
                    Task { await reactor.start() }
                } else {
                    reactor.stop()
                }
            }
        )
    }

    var body: some View {
        MandazaCanvas(size: screenSize,
                      seed: seed,
                      paletteId: paletteId,
                      config: settings.engineConfig(),
                      cadence: cadence,
                      fill: CGSize(width: 1.18, height: 1.18),
                      onIdleChange: handleIdle,
                      modulationSource: reactor.source)
            .frame(width: screenSize.width, height: screenSize.height)
            .focusable()
            .digitalCrownRotation($crown,
                                  from: 0,
                                  through: Double(max(1, Palette.all.count - 1)),
                                  by: 1,
                                  sensitivity: .low,
                                  isContinuous: true,
                                  isHapticFeedbackEnabled: true)
            .onChange(of: crown) { _, value in
                paletteIndex = Int(value.rounded())
            }
            // Exclusive: a successful long press must NOT also fire the tap
            // (which would regenerate and unpin behind the sheet).
            .gesture(
                LongPressGesture(minimumDuration: 0.6)
                    .onEnded { _ in showSheet = true }
                    .exclusively(before: TapGesture().onEnded { regenerate() })
            )
            .contentShape(Rectangle())
            .background(Color.black)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                if showFromPhone {
                    Text("From iPhone")
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6), in: Capsule())
                        .transition(.opacity)
                }
            }
            .sheet(isPresented: $showSheet) {
                WatchSettingsSheet(musicMode: musicModeBinding,
                                   micDenied: reactor.state == .denied,
                                   lastSyncDate: lastSyncAt > 0
                                       ? Date(timeIntervalSince1970: lastSyncAt)
                                       : nil,
                                   onDone: { showSheet = false })
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    regenTask?.cancel()
                    reactor.stop()
                }
            }
            .onChange(of: luminanceReduced) { _, reduced in
                // The canvas pauses itself under Always-On; the mic must stop too.
                if reduced { reactor.stop() }
            }
            .onAppear {
                wireSyncHooks()
                if let snap = settings.pinnedSnapshot {
                    apply(snapshot: snap, announce: false)
                } else if let i = Palette.all.firstIndex(where: { $0.id == settings.paletteId }) {
                    paletteIndex = i
                    crown = Double(i)
                }
            }
            .onDisappear {
                regenTask?.cancel()
                fromPhoneTask?.cancel()
                reactor.stop()
            }
    }

    // MARK: - iPhone sync

    private func wireSyncHooks() {
        WatchSyncController.shared.onSettingsReceived = {
            lastSyncAt = Date().timeIntervalSince1970
            if let snap = settings.pinnedSnapshot {
                // A pushed design stays pinned until the user taps —
                // an incoming settings context must not mutate it.
                apply(snapshot: snap, announce: false)
            } else if let i = Palette.all.firstIndex(where: { $0.id == settings.paletteId }) {
                paletteIndex = i
                crown = Double(i)
            }
        }
        WatchSyncController.shared.onSnapshotReceived = { snap in
            settings.pinnedSnapshot = snap
            apply(snapshot: snap, announce: true)
        }
    }

    private func apply(snapshot snap: MandazaSnapshot, announce: Bool) {
        regenTask?.cancel()
        settings.applyLook(from: snap.config)
        settings.paletteId = snap.paletteId
        if let i = Palette.all.firstIndex(where: { $0.id == snap.paletteId }) {
            paletteIndex = i
            crown = Double(i)
        }
        seed = UUID(uuidString: snap.seed) ?? UUID()
        guard announce else { return }
        fromPhoneTask?.cancel()
        withAnimation { showFromPhone = true }
        fromPhoneTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation { showFromPhone = false }
        }
    }

    // MARK: - Regeneration

    private func regenerate() {
        regenTask?.cancel()
        // A manual tap always returns to generative mode.
        settings.pinnedSnapshot = nil
        seed = UUID()
    }

    /// When a pattern finishes drawing, hold it briefly then auto-redesign —
    /// unless auto-redesign is off or a design pushed from iPhone is pinned.
    private func handleIdle(_ idle: Bool) {
        regenTask?.cancel()
        guard idle, scenePhase == .active,
              settings.watchAutoRegen,
              settings.pinnedSnapshot == nil else { return }
        regenTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(settings.watchAutoRegenSeconds))
            guard !Task.isCancelled, scenePhase == .active else { return }
            seed = UUID()
        }
    }
}
