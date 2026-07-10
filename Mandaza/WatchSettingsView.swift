import SwiftUI
import WatchConnectivity

/// Settings screen for the paired Apple Watch: pairing status plus the
/// watch-only auto-redesign controls. Pushed as a NavigationLink from the
/// settings sheet; mirrors look changes to the watch via
/// `WatchSyncController.pushSettings` (debounced in the controller).
struct WatchSettingsView: View {
    @Bindable var settings: MandazaSettings

    private var controller: WatchSyncController { .shared }

    private var isAvailable: Bool {
        WCSession.isSupported() && controller.isPaired && controller.isWatchAppInstalled
    }

    var body: some View {
        let accent = BL.accent(for: settings.paletteId)
        return Form {
            statusSection(accent: accent)
            controlsSection(accent: accent)
            clockSection(accent: accent)
        }
        .scrollContentBackground(.hidden)
        .background(BL.void.ignoresSafeArea())
        .tint(accent)
        .navigationTitle("Apple Watch")
        .toolbarBackground(BL.void, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear { push() }
        .onChange(of: syncFingerprint) { push() }
    }

    /// One value covering every watch-relevant setting, so a single onChange
    /// pushes on any look/behavior change (the controller debounces).
    private var syncFingerprint: String {
        [settings.paletteId,
         settings.geometryPreset,
         String(settings.drawSpeed),
         String(settings.lineWidth),
         String(settings.glow),
         String(settings.glowStrength),
         String(settings.density),
         String(settings.watchAutoRegen),
         String(settings.watchAutoRegenSeconds)].joined(separator: "|")
    }

    private func push() {
        guard isAvailable else { return }
        WatchSyncController.shared.pushSettings(settings)
    }

    // MARK: - Sections

    @ViewBuilder
    private func statusSection(accent: Color) -> some View {
        Section {
            if !WCSession.isSupported() || !controller.isPaired {
                statusRow(icon: "applewatch.slash",
                          text: "No Apple Watch paired.",
                          dotColor: BL.muted,
                          dotBright: false)
            } else if !controller.isWatchAppInstalled {
                statusRow(icon: "applewatch",
                          text: "Install Mandaza on your watch from the Watch app.",
                          dotColor: BL.amber,
                          dotBright: false)
            } else {
                statusRow(icon: "applewatch",
                          text: controller.isReachable
                              ? "Watch connected."
                              : "Watch paired — syncs when it's next awake.",
                          dotColor: controller.isReachable ? BL.green : BL.muted,
                          dotBright: controller.isReachable)
            }
        } header: {
            blHeader("Status", accent: accent)
        }
        .listRowBackground(BL.deep)
    }

    @ViewBuilder
    private func controlsSection(accent: Color) -> some View {
        Section {
            Toggle("Auto-redesign", isOn: $settings.watchAutoRegen)
                .font(.bl(15))
                .foregroundStyle(BL.paper)
                .accessibilityHint("Draws a new mandala on your watch automatically.")

            if settings.watchAutoRegen {
                Stepper(value: $settings.watchAutoRegenSeconds, in: 3 ... 60, step: 1) {
                    HStack {
                        Text("Every")
                            .font(.bl(15))
                            .foregroundStyle(BL.paper)
                        Spacer()
                        Text("\(Int(settings.watchAutoRegenSeconds))s")
                            .font(.blMono(12))
                            .foregroundStyle(BL.muted)
                    }
                }
                .accessibilityLabel("Auto-redesign interval")
                .accessibilityValue("\(Int(settings.watchAutoRegenSeconds)) seconds")
            }

            Button("Sync Now") { push() }
                .font(.bl(15))
                .foregroundStyle(accent)
                .accessibilityHint("Sends the current look to your watch.")
        } header: {
            blHeader("Auto-Redesign", accent: accent)
        } footer: {
            Text("Your watch mirrors this iPhone's look — palette, density, glow, and line width.")
                .font(.bl(12))
                .foregroundStyle(BL.muted)
        }
        .listRowBackground(BL.deep)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.45)
    }

    /// Compact clock controls: the two highest-impact choices (form + size)
    /// backed by the shared settings store.
    @ViewBuilder
    private func clockSection(accent: Color) -> some View {
        Section {
            Picker("Form", selection: $settings.zenClockFormRaw) {
                Text("Digital").tag(ZenClockForm.digital.rawValue)
                Text("Stacked").tag(ZenClockForm.stacked.rawValue)
                Text("Editorial").tag(ZenClockForm.editorial.rawValue)
            }
            .pickerStyle(.menu)
            .font(.bl(15))
            .foregroundStyle(BL.paper)

            Slider(value: $settings.zenClockSizeScale, in: 0.5 ... 1.8) {
                Text("Size")
            }
            .accessibilityLabel("Clock size")
            .accessibilityValue("\(Int(settings.zenClockSizeScale * 100)) percent")
        } header: {
            blHeader("Clock", accent: accent)
        }
        .listRowBackground(BL.deep)

        Section {
            Toggle("Tilt parallax", isOn: Binding(
                get: { settings.zenTiltIntensity != .off },
                set: { on in
                    if on {
                        if settings.zenTiltIntensity == .off {
                            settings.zenTiltIntensity = .pronounced
                        }
                    } else {
                        settings.zenTiltIntensity = .off
                    }
                }
            ))
            .font(.bl(15))
            .foregroundStyle(BL.paper)
            if settings.zenTiltIntensity != .off {
                Picker("Intensity", selection: $settings.zenTiltIntensityRaw) {
                    Text("Subtle").tag(ZenTiltIntensity.subtle.rawValue)
                    Text("Pronounced").tag(ZenTiltIntensity.pronounced.rawValue)
                }
                .pickerStyle(.menu)
                .font(.bl(15))
                .foregroundStyle(BL.paper)
            }
        } header: {
            blHeader("Parallax", accent: accent)
        }
        .listRowBackground(BL.deep)
    }

    // MARK: - Rows

    private func statusRow(icon: String, text: String, dotColor: Color, dotBright: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(BL.muted)
            Text(text)
                .font(.bl(15))
                .foregroundStyle(BL.paper)
            Spacer()
            BLDot(color: dotColor, size: 8, bright: dotBright)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    @ViewBuilder
    private func blHeader(_ label: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            BLDot(color: accent, size: 6)
            BLCaption(label)
        }
        .padding(.top, 4)
    }
}
