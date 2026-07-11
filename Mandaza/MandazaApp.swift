import SwiftUI

@main
struct MandazaApp: App {
    var body: some Scene {
        WindowGroup {
            #if os(tvOS)
            TVContentView()
                .preferredColorScheme(.dark)
            #else
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
            #endif
        }
    }
}
