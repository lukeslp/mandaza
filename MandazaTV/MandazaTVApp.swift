/*
 File Purpose: tvOS application entry point for Mandaza — launches the ambient
 fullscreen SwiftUI experience shared with the iOS engine.

 Primary Components:
 - `MandazaTVApp` — `@main` scene container.

 Inputs / Outputs:
 - Inputs: system lifecycle.
 - Outputs: `TVContentView` hosted in a `WindowGroup`.
 */

import SwiftUI

@main
struct MandazaTVApp: App {
    var body: some Scene {
        WindowGroup {
            TVContentView()
                .preferredColorScheme(.dark)
        }
    }
}
