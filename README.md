# Mandaza

A native iOS, Android, watchOS, Wear OS, and tvOS app that draws animated hexagonal-loop
mandalas in real time. On iPhone and iPad it ships Home Screen / StandBy
widgets and exports wallpaper-resolution images. On Apple Watch it runs as
a live companion face; Pixel Watch has a native round-screen companion powered
by the same deterministic engine. On Apple TV it runs as a fullscreen ambient
experience with on-screen quick controls (Apple TV has no third-party
WidgetKit surface).

The creative experience runs on-device with no analytics or account. The
Google Play and Amazon builds make no network requests; the direct-download
build checks the Mandaza release catalog once per day for updates.

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
the standalone `MandazaTV` scheme.

### Apple TV (tvOS)

```sh
xcodegen
xcodebuild -scheme MandazaTV \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  build
```

**TestFlight / App Store (tvOS)** — MandazaTV is a separate Apple TV product,
[Apple ID 6768536771](https://apps.apple.com/us/app/mandazatv/id6768536771),
with bundle ID `com.lukesteuber.mandaza.tv`:

> The `TV_OS` 1.0 draft under the unified `com.lukesteuber.mandaza` App Store
> record is an abandoned duplicate. Ignore it permanently: do not attach a
> build, upload metadata, or submit it. Any Apple TV maintenance belongs only
> to the standalone MandazaTV record above.

```sh
scripts/archive-tvos.sh
scripts/export-ipa-tvos.sh
scripts/upload-testflight.sh --tvos
```

See [TESTFLIGHT.md](TESTFLIGHT.md) (tvOS section) and [PROVISIONING.md](PROVISIONING.md).

### Fire TV and Samsung TV

The non-Apple living-room tracks are independent packages:

- **Fire TV / Android TV:** native Compose module `android/tv`, application ID
  `app.mandaza.tv`. Its mobile-style New / Zen / Tune rails and glow-free
  bounded renderer are running on a physical AFTTI43. See
  [android/FIRE-TV.md](android/FIRE-TV.md).
- **Samsung TV:** offline Tizen widget under `samsung/tizen`, installed on a
  physical UN50TU8000FXZA. It uses a compatibility-safe incremental 1080p
  canvas with glow disabled. See [samsung/RELEASE.md](samsung/RELEASE.md).

These tracks share Mandaza’s visual language but do not share store identities,
signing, or release evidence with the standalone Apple TV app.

The Fire-tablet build is a third independent release track: the native Android
app uses package `app.mandaza.android`, the `amazon` flavor, and version code
`10306`. It omits both the direct updater and Google Play Review. See
[android/AMAZON-RELEASE.md](android/AMAZON-RELEASE.md).

## Submission Pack

For paste-ready App Store metadata, review notes, privacy/compliance checklist, asset checklist, and iOS/tvOS upload runbooks, use [APP_STORE_PACK.md](APP_STORE_PACK.md).

**Remote:** Play/Pause creates a new pattern. **Menu** toggles the dock. When the dock is hidden, **click the touch surface** for a new pattern (same idea as tapping the canvas on iPhone), or **swipe** / Menu to bring the dock back. A focused full-screen control receives remote events so Menu does not exit to the TV home screen. When the dock hides, a small top chip briefly reminds
you that **Menu** restores controls (the art stays primary). Zen clock type is
scaled for 10-foot viewing.

The `MandazaTV` target has its own app entry point, bundle ID, signing profile,
store record, and TV assets while sharing `MandazaCore` with the iOS app.

**Physical Apple TV:** Xcode needs a **registered device** and matching tvOS
**App ID**. The target retains the live App ID's App Group entitlement, while
tvOS preferences remain local to MandazaTV.
Step-by-step: [PROVISIONING.md](PROVISIONING.md).

## Project layout

```
Mandaza/                      iOS/iPadOS app target
  MandazaApp.swift            iOS app entry point
  ContentView.swift           Top-level UI: canvas + control bar + settings + favorites
  ExportService.swift         PHPhotoLibrary save + wallpaper presets
  Mandaza.entitlements        App Group: group.com.lukesteuber.mandaza
  Assets.xcassets/            AppIcon, AccentColor, LaunchSplashIOS
  Info.plist                  Generated by xcodegen

MandazaCore/                  Sources shared across Apple targets
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

MandazaTV/                    standalone tvOS app target
  MandazaTVApp.swift          tvOS app entry point
  TVContentView.swift         Fullscreen canvas + panels + Zen clock
  Assets.xcassets/            AppIcon.brandassets (tv), AccentColor, LaunchSplashTV
  MandazaTV.entitlements      Existing App Group capability for TV App ID
  Info.plist                  Generated by xcodegen

android/tv/                   Fire TV / Android TV Compose app
samsung/tizen/                Samsung Tizen offline widget

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
clock forms, tilt parallax, Watch companion, and Home/StandBy widgets. The
standalone tvOS release remains separate; Fire TV and Samsung TV are active
device-tested release tracks. Fire's lifecycle/long-run gate is complete;
Samsung's remote/lifecycle/long-run and store-signing gates remain open.
Amazon MandazaTV `app.mandaza.tv` 1.3.1 (20301) is Live; its final
store-delivered install and Apps-row banner check remain open.
**Permanent distribution boundary:** the `TV_OS` 1.0 draft under the unified
Mandaza record (`com.lukesteuber.mandaza`) is a redundant abandoned record. Do
not attach, complete, submit, or otherwise revive it. The already-live
MandazaTV record (`com.lukesteuber.mandaza.tv`, Apple ID 6768536771) remains
the only Apple TV product.
The privacy policy is maintained in `docs/index.md` and `docs/privacy.html` and
is published at [mandaza.app/privacy.html](https://mandaza.app/privacy.html).
