// File Purpose: Hosts the live Apple Watch mandala face and its interaction,
// sync, audio, parallax, and regeneration lifecycle.
// Primary Components: WatchRootView, WatchConnectivity callbacks, sensor
// lifecycle reconciliation, and automatic pattern regeneration.
// I/O: Reads shared settings, crown/gesture/sensor input, and iPhone sync;
// outputs the animated face, settings sheet, haptics, and visual status.

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settings = MandazaSettings.shared
    @State private var configOverride: EngineConfig?
    @State private var seed = UUID().uuidString
    @State private var paletteIndex = 0
    @State private var crown = 0.0
    @State private var regenTask: Task<Void, Never>?
    @State private var lastIdle = false

    @State private var reactor = AudioReactor()
    @State private var tilt = TiltProvider()
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

    private var paletteName: String {
        Palette.by(id: paletteId).name
    }

    private var cadence: MandazaCadence {
        guard scenePhase == .active else { return .paused }
        return .interval(reactor.source.isActive ? 1.0 / 24.0 : 1.0 / 18.0)
    }

    private var lastSyncDate: Date? {
        lastSyncAt > 0 ? Date(timeIntervalSince1970: lastSyncAt) : nil
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
        lifecycleCanvas
    }

    private var liveCanvas: some View {
        MandazaCanvas(size: screenSize,
                      seed: seed,
                      paletteId: paletteId,
                      config: configOverride ?? settings.engineConfig(),
                      cadence: cadence,
                      fill: CGSize(width: 1.18, height: 1.18),
                      reactivity: settings.reactivity,
                      onIdleChange: handleIdle,
                      modulationSource: reactor.source,
                      parallaxSource: settings.zenTiltEnabled && !reduceMotion
                          ? tilt : nil,
                      parallaxDepthContrast: settings.zenTiltDepth,
                      parallaxInvertDepth: settings.zenTiltInvertDepth,
                      theme: settings.canvasTheme)
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
                settings.paletteId = paletteId
            }
    }

    private var accessibleCanvas: some View {
        liveCanvas
            // Exclusive: a successful long press must NOT also fire the tap
            // (which would regenerate and unpin behind the sheet).
            .gesture(
                LongPressGesture(minimumDuration: 0.6)
                    .onEnded { _ in showSheet = true }
                    .exclusively(before: TapGesture().onEnded { regenerate() })
            )
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mandaza pattern")
            .accessibilityValue("\(paletteName) palette")
            .accessibilityHint("Double tap for a new pattern. Swipe up or down to change the palette. Use Actions for Settings.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { regenerate() }
            .accessibilityAction(named: "Settings") { showSheet = true }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: adjustPalette(by: 1)
                case .decrement: adjustPalette(by: -1)
                @unknown default: break
                }
            }
    }

    private var presentedCanvas: some View {
        accessibleCanvas
            .background(BL.canvasGround(for: settings.canvasTheme))
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
                                   lastSyncDate: lastSyncDate,
                                   onDone: { showSheet = false })
            }
    }

    private var lifecycleCanvas: some View {
        presentedCanvas
            .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
            .onChange(of: luminanceReduced) { _, reduced in
                // The canvas pauses itself under Always-On; sensors stop too.
                if reduced { reactor.stop() }
                applyTilt()
            }
            .onChange(of: reduceMotion) { _, reduced in handleReduceMotion(reduced) }
            .onChange(of: settings.zenTiltEnabled) { _, _ in applyTilt() }
            .onChange(of: settings.zenTiltAmount) { _, _ in applyTilt() }
            .onChange(of: settings.zenTiltAxesRaw) { _, _ in applyTilt() }
            .onAppear(perform: handleAppear)
            .onDisappear(perform: handleDisappear)
    }

    private func handleAppear() {
        wireSyncHooks()
        applyTilt()
        if let snapshot = settings.pinnedSnapshot {
            apply(snapshot: snapshot, announce: false)
        } else {
            configOverride = nil
            restorePalette(id: settings.paletteId)
        }
    }

    private func handleDisappear() {
        regenTask?.cancel()
        fromPhoneTask?.cancel()
        reactor.stop()
        tilt.stop()
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active, lastIdle, !reduceMotion {
            handleIdle(true)
        } else if phase != .active {
            regenTask?.cancel()
            reactor.stop()
        }
        applyTilt()
    }

    private func handleReduceMotion(_ reduced: Bool) {
        applyTilt()
        if reduced {
            regenTask?.cancel()
        } else if lastIdle, scenePhase == .active {
            handleIdle(true)
        }
    }

    private func restorePalette(id: String) {
        guard let index = Palette.all.firstIndex(where: { $0.id == id }) else { return }
        paletteIndex = index
        crown = Double(index)
    }

    /// Runs watch parallax only while the face is active and fully lit.
    /// The provider uses a lower watchOS sampling cadence to protect battery.
    private func applyTilt() {
        guard scenePhase == .active,
              !luminanceReduced,
              !reduceMotion,
              settings.zenTiltEnabled else {
            tilt.stop()
            return
        }
        tilt.viewSize = screenSize
        tilt.ambientSway = false
        tilt.start(amount: settings.zenTiltAmount, axes: settings.zenTiltAxes)
    }

    // MARK: - iPhone sync

    private func wireSyncHooks() {
        WatchSyncController.shared.onSettingsReceived = {
            lastSyncAt = Date().timeIntervalSince1970
            if let snap = settings.pinnedSnapshot {
                // A pushed design stays pinned until the user taps —
                // an incoming settings context must not mutate it.
                apply(snapshot: snap, announce: false)
            } else {
                configOverride = nil
                restorePalette(id: settings.paletteId)
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
        configOverride = snap.config
        settings.paletteId = snap.paletteId
        restorePalette(id: snap.paletteId)
        seed = snap.seed
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
        configOverride = nil
        seed = UUID().uuidString
    }

    private func adjustPalette(by delta: Int) {
        guard !Palette.all.isEmpty else { return }
        let count = Palette.all.count
        paletteIndex = ((paletteIndex + delta) % count + count) % count
        crown = Double(paletteIndex)
        settings.paletteId = paletteId
    }

    /// When a pattern finishes drawing, hold it briefly then auto-redesign —
    /// unless auto-redesign is off or a design pushed from iPhone is pinned.
    private func handleIdle(_ idle: Bool) {
        lastIdle = idle
        regenTask?.cancel()
        guard idle, scenePhase == .active,
              !reduceMotion,
              settings.watchAutoRegen,
              settings.pinnedSnapshot == nil else { return }
        regenTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(settings.watchAutoRegenSeconds))
            guard !Task.isCancelled, scenePhase == .active, !reduceMotion else { return }
            configOverride = nil
            seed = UUID().uuidString
        }
    }
}
