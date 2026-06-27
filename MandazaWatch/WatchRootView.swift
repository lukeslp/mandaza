import SwiftUI

/// The watch face: a full-screen live mandala.
///
/// - Tap to regenerate a new pattern.
/// - Digital Crown cycles the palette.
/// - Engine settings (geometry, glow, line width) come from the shared App
///   Group, so the watch honors the same look configured on iPhone.
///
/// Battery: the canvas runs at a throttled cadence while the app is active and
/// freezes when the wrist drops / the app backgrounds. `MandazaCanvas` also
/// pauses automatically under Always-On luminance reduction.
struct WatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = MandazaSettings.shared
    @State private var seed = UUID()
    @State private var paletteIndex = 0
    @State private var crown = 0.0

    private var paletteId: String {
        guard !Palette.all.isEmpty else { return "aurora" }
        let count = Palette.all.count
        return Palette.all[((paletteIndex % count) + count) % count].id
    }

    private var cadence: MandazaCadence {
        scenePhase == .active ? .interval(1.0 / 18.0) : .paused
    }

    var body: some View {
        GeometryReader { geo in
            MandazaCanvas(size: geo.size,
                          seed: seed,
                          paletteId: paletteId,
                          config: settings.engineConfig(),
                          cadence: cadence)
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
                .onTapGesture { seed = UUID() }
                .contentShape(Rectangle())
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear {
            if let i = Palette.all.firstIndex(where: { $0.id == settings.paletteId }) {
                paletteIndex = i
                crown = Double(i)
            }
        }
    }
}
