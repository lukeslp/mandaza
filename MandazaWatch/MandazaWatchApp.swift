import SwiftUI

/// watchOS companion: a live animated-mandala watch face. A thin shell over the
/// shared MandazaKit engine, mirroring how the iOS and tvOS apps host
/// `MandazaCanvas`.
@main
struct MandazaWatchApp: App {
    init() {
        // Activate at launch (not first view appearance) so settings context
        // and queued snapshots delivered while the app was dead land promptly.
        WatchSyncController.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
