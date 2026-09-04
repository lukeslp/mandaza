# MandazaTV — Fire TV / Android TV track

**Goal:** Living-room MandazaTV experience on Amazon Fire TV (Appstore).  
**Not:** phone Mandaza, Fire tablet-first listing (second goal).

## Product identity

| | |
|---|---|
| Module | `:tv` |
| Application ID | `app.mandaza.tv` |
| Version code band | `20300+` (phone uses `103xx`) |
| Launcher | `LEANBACK_LAUNCHER` (+ optional `LAUNCHER` for sideload smoke) |
| Features | `leanback` + `touchscreen` **required=false** (universal-capable later) |
| Apple sibling | `com.lukesteuber.mandaza.tv` (tvOS — separate store) |

## Build

```sh
cd android
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export ANDROID_HOME="$HOME/Library/Android/sdk"
./gradlew :tv:assembleDebug
# APK: tv/build/outputs/apk/debug/tv-debug.apk
# Install on Fire Stick / emulator:
# adb install -r tv/build/outputs/apk/debug/tv-debug.apk
```

Signed release (same keystore as phone Mandaza):

```sh
cd /Users/luke/workspace/android-release-toolkit
scripts/android-release with-signing --profile mandaza -- \
  sh -c 'cd /Users/luke/workspace/mandaza-ios/android && ./gradlew :tv:assembleRelease'
```

## Remote model

| Input | Action |
|---|---|
| Play / Play-Pause | New pattern from any state |
| Select / Enter with controls hidden | New pattern |
| Select / Enter with controls visible | Activate the selected rail item |
| ← / → | Move across the active rail |
| ↑ / ↓ with Tune open | Move between the primary and Tune rails |
| Directional input with controls hidden | Show the primary rail |
| Back | Leave Zen, close Tune, or toggle the primary rail |

The primary rail is **New · Zen · Tune**. Tune contains previous/next palette,
Void/Paper canvas, and clock visibility. Zen hides the rails and centers the
clock over the canvas.

## Physical Fire TV status (2026-08-09)

- Device: Amazon AFTTI43 (`brandenburg`), Fire OS 7 / Android 9 at the local
  developer endpoint `192.168.0.120:5555`.
- Panel: physical 3840×2160; Amazon framebuffer and Android app override are
  1920×1080 at 60 Hz. Do not run `wm size reset` for this app.
- Renderer: native Compose/Kotlin engine, glow and idle color pulse disabled.
  Geometry is capped at logical 1920×1080 and scales to fill if a future
  firmware exposes a 4K app surface.
- Efficiency: frame advancement is bounded to one 30 Hz interval, palette
  colors are cached, the clock updates only while visible in Zen, and the
  canvas frame loop stops when the longest path completes.
- Device evidence: signed `1.3.1 (20301)` APK installed/launched; D-pad
  primary/Tune rails and Zen verified; five 1920×1080 screenshots captured.
  After a measured reveal, total
  rendered frames held at 338 across later idle samples (median 22 ms, p90
  31 ms during the reveal).
- Lifecycle evidence: Home/resume and sleep/wake completed on the signed release.
  A 30-minute foreground observation retained one process, held the display
  awake, settled at roughly 38–40 MB PSS after warm-up, and produced no
  Mandaza crash or ANR entries. The APK requests no network permission, so the
  cold-launch path has no service dependency.

## Live Amazon follow-up

1. Install the Amazon-delivered 1.3.1 (20301) package and confirm the production
   Apps-row banner, cold launch, core remote flow, and signature lineage.
2. Optional maintenance: consolidate the `tv` canvas with phone
   `MandazaCanvas` without changing the validated TV cadence.

## Ambient Time

Ambient Time TV is a separate package and release track. Its development must
not change MandazaTV's identity, artifact, listing evidence, or submission state.

## Amazon staging status

- Listing copy/icons: `tv/amazon-listing/`; five physical Fire screenshots from
  the signed release cover the main rail, Zen, Tune, Paper, and ambient states.
- In-app banner: real Top Shelf–derived PNG
- Signed release: `tv/dist/release/MandazaTV-1.3.1-release.apk`, version code
  `20301`, SHA-256 `1dfbfeee87d3a87cee31f68c150d96f58a1a0134b4c9350f799139ed44499023`.
- Amazon record: Live as of 2026-09-04, portal app id
  `amzn1.devportal.mobileapp.0130d2b1a19447bb9d6367e7741d1e3b`, release id
  `amzn1.devportal.apprelease.c42c655564a64765b02f0124762f9c6f`.
- Device smoke: that exact signed APK is installed/launched on the physical
  AFTTI43 and the primary, Zen, Tune, Paper, and hidden-control flows were
  exercised on 2026-08-09. Home/resume, sleep/wake, and the 30-minute
  foreground stability gate completed on 2026-08-10.
- Open: the store-delivered build and production Apps-row banner have not yet
  been checked; the evidence above belongs to the local signed candidate, not
  a download from Amazon.

See [AMAZON-RELEASE.md](AMAZON-RELEASE.md).
