/*
 File Purpose: Hosts Mandaza's full-screen watchOS mandala experience.
 Primary Components: WatchRootView, Digital Crown palette selection, automatic
 regeneration, and accessibility actions.
 Inputs / Outputs: Reads shared settings and watch lifecycle state; renders a
 live canvas, changes palettes, and generates new local seeds.
 */

import SwiftUI
import WatchKit

/// The watch face: a full-screen live mandala.
///
/// - Tap to regenerate a new pattern.
/// - Digital Crown cycles the palette.
/// - After a pattern finishes drawing it pauses, then auto-redesigns.
/// - Engine settings persist in the watch-local App Group. iPhone and Watch
///   containers do not synchronize without WatchConnectivity.
///
/// Sizing: the canvas is framed to `WKInterfaceDevice.screenBounds` so the
/// engine is laid out for the exact watch screen (rather than a GeometryReader
/// size that can disagree with the rendered Canvas and squash the pattern into
/// a portrait strip). Battery: throttled cadence while active, frozen when the
/// wrist drops / the app backgrounds; MandazaCanvas also pauses under Always-On.
struct WatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settings = MandazaSettings.shared
    @State private var seed = UUID()
    @State private var paletteIndex = 0
    @State private var crown = 0.0
    @State private var regenTask: Task<Void, Never>?
    @State private var lastIdle = false

    /// Seconds to hold a finished pattern before auto-redesigning.
    private let autoRegenDelay: Double = 6

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
        scenePhase == .active ? .interval(1.0 / 18.0) : .paused
    }

    var body: some View {
        MandazaCanvas(size: screenSize,
                      seed: seed.uuidString,
                      paletteId: paletteId,
                      config: settings.engineConfig(),
                      cadence: cadence,
                      fill: CGSize(width: 1.18, height: 1.18),
                      onIdleChange: handleIdle)
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
            .onTapGesture { regenerate() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mandaza pattern")
            .accessibilityValue("\(paletteName) palette")
            .accessibilityHint("Double tap for a new pattern. Swipe up or down to change the palette.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { regenerate() }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    adjustPalette(by: 1)
                case .decrement:
                    adjustPalette(by: -1)
                @unknown default:
                    break
                }
            }
            .contentShape(Rectangle())
            .background(Color.black)
            .ignoresSafeArea()
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, lastIdle, !reduceMotion {
                    handleIdle(true)
                } else if phase != .active {
                    regenTask?.cancel()
                }
            }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced {
                    regenTask?.cancel()
                } else if lastIdle, scenePhase == .active {
                    handleIdle(true)
                }
            }
            .onAppear(perform: restoreSavedPalette)
            .onDisappear { regenTask?.cancel() }
    }

    private func regenerate() {
        regenTask?.cancel()
        seed = UUID()
    }

    private func adjustPalette(by delta: Int) {
        guard !Palette.all.isEmpty else { return }
        let count = Palette.all.count
        paletteIndex = ((paletteIndex + delta) % count + count) % count
        crown = Double(paletteIndex)
        settings.paletteId = paletteId
    }

    private func restoreSavedPalette() {
        let savedPaletteID = settings.paletteId
        guard let index = Palette.all.firstIndex(where: { palette in
            palette.id == savedPaletteID
        }) else { return }
        paletteIndex = index
        crown = Double(index)
    }

    /// When a pattern finishes drawing, hold it briefly then auto-redesign.
    private func handleIdle(_ idle: Bool) {
        lastIdle = idle
        regenTask?.cancel()
        guard idle, scenePhase == .active, !reduceMotion else { return }
        regenTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(autoRegenDelay))
            guard !Task.isCancelled, scenePhase == .active else { return }
            seed = UUID()
        }
    }
}
