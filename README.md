# Mandaza

A native iOS, watchOS, and tvOS app that draws animated hexagonal-loop
mandalas in real time. On iPhone and iPad it ships Home Screen / StandBy
widgets and exports wallpaper-resolution images. On Apple Watch it runs as
a live companion face. On Apple TV it runs as a fullscreen ambient
experience with on-screen quick controls (Apple TV has no third-party
WidgetKit surface).

100% on-device. No network. No analytics. No account.

## Features

- **Animated canvas.** SwiftUI `Canvas` + `TimelineView` renders a fresh
  hexagonal-loop pattern on every canvas tap, stroking each loop
  progressively with optional glow (off by default; regenerate may turn on a
  soft bloom less than half the time).
- **12 palettes** — Aurora, Sunset, Ember, Bioluminescent, Vaporwave,
  Cyberpunk, Risograph, Oxblood, Canopy, Dichromat, Amber, Terrain.
- **Zen Mode** — center footer button drops into Zen: large clock over the
  mandala, optional auto-regenerating patterns. Digital, stacked, and
  editorial clock forms; opacity, type, size, and eight positions.
- **Music responsivity** — in Zen, optional microphone-driven beat pump and
  speed-up (Reactivity slider). Audio is never recorded or stored.
- **Tilt parallax** — Amount slider, depth-layer contrast, invert depth,
  and axis lock (both / horizontal / vertical). Brighter strokes sit nearer
  by default; Zen adds a faint long-period sway at rest. Reduce Motion
  disables sampling.
- **Canvas look** — Void (neon on black) or Paper (warm parchment with soft
  ink shadows — light-theme experiment).
- **Footer** — History · Favorites · Zen · Settings · Save.
- **Favorites** — heart any mandala to keep it; favorites cycle into widget
  rotation automatically. Loading a favorite or **Previous** snapshot also
  restores density, geometry, and stroke look from the saved `EngineConfig`.
- **Density + geometry controls** — pattern editability without the curated
  feel slipping.
- **Widgets**
  - StandBy (`.systemLarge` / `.systemExtraLarge`) with time HUD
  - Home Screen (`.systemSmall` / `.systemMedium`)
  - Each widget instance is configurable via Edit Widget: palette, rotation
    interval, show-time toggle.
- **Apple Watch companion** — live face, tap to regenerate, Digital Crown
  for palettes, long-press settings, auto-mirror from iPhone, Send to Watch.
- **`mandaza://`** URL scheme — tap a widget to open the app at that exact
  seed.
- **Export** to Photos at iPhone Pro / Standard / iPad / Square 4K presets.
  Rendering is off-main via `UIGraphicsImageRenderer`, so the UI never
  hangs while saving.
- **Accessibility** — VoiceOver labels on every control, `accessibilityReduceMotion`
  honored (skips animation, disables auto-regen), `isLuminanceReduced`
  pauses the engine during Always-On.

## Build

```sh
brew install xcodegen          # if you don't already have it
xcodegen
open Mandaza.xcodeproj
```

From the command line:

```sh
xcodegen
xcodebuild -scheme Mandaza \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

xcodebuild -scheme Mandaza \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

**Release archives:** `scripts/archive.sh` regenerates the project with XcodeGen,
runs **unit tests** on the iPhone 17 simulator (override with `SKIP_TESTS=1` to
skip), then produces `build/Mandaza.xcarchive`. `scripts/archive-tvos.sh` runs a
tvOS Simulator **Debug build** smoke first (same skip flag), then archives
the same `Mandaza` scheme for a tvOS destination.

### Apple TV (tvOS)

```sh
xcodegen
xcodebuild -scheme Mandaza \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  build
```

**TestFlight / App Store (tvOS)** — tvOS ships from the same multiplatform app record and bundle ID, `com.lukesteuber.mandaza`:

```sh
scripts/archive-tvos.sh
scripts/export-ipa-tvos.sh
scripts/upload-testflight.sh --tvos
```

See [TESTFLIGHT.md](TESTFLIGHT.md) (tvOS section) and [PROVISIONING.md](PROVISIONING.md).

## Submission Pack

For paste-ready App Store metadata, review notes, privacy/compliance checklist, asset checklist, and iOS/tvOS upload runbooks, use [APP_STORE_PACK.md](APP_STORE_PACK.md).

**Remote:** Play/Pause creates a new pattern. **Menu** toggles the dock. When the dock is hidden, **click the touch surface** for a new pattern (same idea as tapping the canvas on iPhone), or **swipe** / Menu to bring the dock back. A focused full-screen control receives remote events so Menu does not exit to the TV home screen. When the dock hides, a small top chip briefly reminds
you that **Menu** restores controls (the art stays primary). Zen clock type is
scaled for 10-foot viewing.

The tvOS build uses the same `Mandaza` app target and switches to `TVContentView`
at compile time. iOS-only Photos, WidgetKit, and Watch settings code is guarded
out of the tvOS build.

**Physical Apple TV:** Xcode needs a **registered device** and matching shared
**App ID**. The tvOS build intentionally has no App Group entitlement.
Step-by-step: [PROVISIONING.md](PROVISIONING.md).

## Project layout

```
Mandaza/                      multiplatform iOS/tvOS app target
  MandazaApp.swift            App entry; selects ContentView or TVContentView by platform
  ContentView.swift           Top-level UI: canvas + control bar + settings + favorites
  ExportService.swift         PHPhotoLibrary save + wallpaper presets
  Mandaza.entitlements        App Group: group.com.lukesteuber.mandaza
  Assets.xcassets/            AppIcon, AccentColor, LaunchSplashIOS
  Info.plist                  Generated by xcodegen

MandazaCore/                  Sources shared between app and widget targets
  MandazaEngine.swift         Algorithm port: cells, dots, loops, beziers + off-main renderImage
  MandazaCanvas.swift         SwiftUI Canvas + TimelineView animation host
  Palettes.swift              12 palettes, CGColor + SwiftUI Color representations
  MandazaSnapshot.swift       Value-type record of one mandala (used by widgets + favorites)
  MandazaSettings.swift       @Observable, App Group-backed persistence + applyLook(from:)
  ZenClockTypography.swift    Shared zen clock weight → Font.Weight + label mapping
  MandazaImageView.swift      Still-image renderer used by widgets and favorites grid
  TiltProvider.swift          CoreMotion parallax (inert on tvOS / macOS host)

MandazaWidgets/               WidgetKit app extension
  MandazaWidgetsBundle.swift  @main bundle (Home + StandBy)
  MandazaWidgets.swift        StandBy / Home Screen widget definitions
  MandazaProvider.swift       Timeline provider (MainActor-isolated settings reads) + rotation logic
  MandazaWidgetIntent.swift   AppIntent for Edit Widget configuration

MandazaWatch/                 watchOS companion face
  WatchRootView.swift         Live canvas + gestures
  WatchSettingsView.swift     On-wrist settings

MandazaTests/                 Unit tests
  EngineTests.swift           Engine determinism + renderImage + palette
  SettingsTests.swift         Settings → engine-config, favorites, typography, applyLook
  SnapshotTests.swift         MandazaSnapshot + EngineConfig Codable round-trip

MandazaTV/                    tvOS surface included by the Mandaza app target
  TVContentView.swift         Fullscreen canvas + panels + Zen clock
  Assets.xcassets/            AppIcon.brandassets (tv), AccentColor, LaunchSplashTV

project.yml                   xcodegen spec (authoritative project source)
scripts/
  apply-brand-assets.py       Resize supplied icon + splash into iOS/tvOS catalog slots
  archive.sh / archive-tvos.sh
```

## Attribution

The hexagonal-loop algorithm is adapted from Charlotte Dann's
[Hexagonal Generative Art](https://codepen.io/pouretrebelle/pen/ZBNJmd) CodePen,
building on David Siaw's Hexlife. Truchet tile mathematics is public domain
(Sébastien Truchet, 1704).

## License

MIT — see [LICENSE](LICENSE).

## Status

Version **1.2** is live. Version **1.3** is prepared with music responsivity,
clock forms, tilt parallax, Watch companion, and Home/Lock/StandBy widgets.
The documented privacy-policy URL currently returns 404 and must be published
and verified before submission.
