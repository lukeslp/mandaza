import SwiftUI

/// Compact settings sheet presented by long-pressing the watch face.
///
/// Purely presentational: the root view owns the audio reactor lifecycle and
/// the synced-settings state. This sheet only surfaces a Music Mode toggle
/// (via the injected binding), a sync-status row, and a Done button, so all
/// behavior stays in `WatchRootView`.
struct WatchSettingsSheet: View {
    @Binding var musicMode: Bool
    var micDenied: Bool = false
    let lastSyncDate: Date?
    let onDone: () -> Void

    var body: some View {
        List {
            Section {
                Toggle("Music Mode", isOn: $musicMode)
                    .disabled(micDenied)
                    .accessibilityLabel("Music Mode")
                    .accessibilityHint("Drives the mandala from live audio")
                if micDenied {
                    // watchOS has no openSettings URL; instructions are the
                    // only recovery path.
                    Text("Microphone access is off. Allow it in the Watch app under Privacy & Security › Microphone › Mandaza.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                if let lastSyncDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Synced from iPhone")
                        Text(lastSyncDate, style: .relative)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Settings synced from iPhone")
                } else {
                    Text("Using defaults — open Mandaza settings on iPhone to sync.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Using default settings. Open Mandaza settings on iPhone to sync.")
                }
            }
            Section {
                Button("Done", action: onDone)
                    .accessibilityHint("Closes settings")
            }
        }
        .navigationTitle("Settings")
    }
}
