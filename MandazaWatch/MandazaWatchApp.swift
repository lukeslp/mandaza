import SwiftUI

/// watchOS companion: a live animated-mandala watch face. A thin shell over the
/// shared MandazaKit engine, mirroring how the iOS and tvOS apps host
/// `MandazaCanvas`.
@main
struct MandazaWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}
