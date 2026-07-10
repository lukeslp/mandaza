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
- **11 palettes** — Aurora, Sunset, Ember, Bioluminescent, Vaporwave,
  Cyberpunk, Risograph, Oxblood, Arctic, Dichromat, Amber.
- **Zen Mode** — center footer button drops into Zen: large clock over the
  mandala, optional auto-regenerating patterns. Digital, stacked, and
  editorial clock forms; opacity, type, size, and eight positions.
- **Music responsivity** — in Zen, optional microphone-driven beat pump and
  speed-up (Reactivity slider). Audio is never recorded or stored.
- **Tilt parallax** — Off / Subtle / Pronounced device-tilt depth on iPhone
  and Apple Watch.
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
`MandazaTV`.

### Apple TV (tvOS)

```sh
xcodegen
xcodebuild -scheme MandazaTV \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  build
```

**TestFlight / App Store (tvOS)** — separate App Store Connect app for `com.lukesteuber.mandaza.tv`. After the tvOS app record exists and signing is green:

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

The tvOS target shares `MandazaCore` only (no Photos, no WidgetKit). Bundle id:
`com.lukesteuber.mandaza.tv`.

**Physical Apple TV:** Xcode needs a **registered device** and matching **App ID** (with App Groups). Step-by-step: [PROVISIONING.md](PROVISIONING.md).

## Project layout

```
Mandaza/                      iOS app
  MandazaApp.swift            App entry
  ContentView.swift           Top-level UI: canvas + control bar + settings + favorites
  ExportService.swift         PHPhotoLibrary save + wallpaper presets
  Mandaza.entitlements        App Group: group.com.lukesteuber.mandaza
  Assets.xcassets/            AppIcon, AccentColor, LaunchSplashIOS
  Info.plist                  Generated by xcodegen

MandazaCore/                  Sources shared between app and widget targets
  MandazaEngine.swift         Algorithm port: cells, dots, loops, beziers + off-main renderImage
  MandazaCanvas.swift         SwiftUI Canvas + TimelineView animation host
  Palettes.swift              11 palettes, CGColor + SwiftUI Color representations
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

MandazaTV/                    tvOS app (ambient / screensaver-style while open)
  MandazaTVApp.swift          App entry
  TVContentView.swift         Fullscreen canvas + panels + Zen clock
  Assets.xcassets/            AppIcon.brandassets (tv), AccentColor, LaunchSplashTV
  Info.plist                  Generated by xcodegen
  MandazaTV.entitlements      Same App Group as iOS (per-device storage)

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

Version **1.3** — music responsivity, clock forms, tilt parallax, Watch
companion, Home/StandBy widgets. Next: App Store Connect upload of metadata
and screenshots, TestFlight beta review.
