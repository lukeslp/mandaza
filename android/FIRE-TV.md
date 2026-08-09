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
- Device evidence: debug APK installed/launched; D-pad primary/Tune rails and
  Zen verified; 1920×1080 screenshot captured. After a measured reveal, total
  rendered frames held at 338 across later idle samples (median 22 ms, p90
  31 ms during the reveal).

## Still to do before Amazon submit

1. Rebuild the signed release APK; the retained 2026-08-08 artifact predates
   the 2026-08-09 renderer and mobile-style rail work.
2. Run sleep/wake, Home/resume, and 30+ minute device gates; watch the
   purgeable Skia path-mask cache during the long run.
3. Replace the inherited tvOS listing screenshots with current physical Fire
   captures of the primary rail, Zen, and Tune states.
4. Bump the Fire version code for the first Amazon upload.
5. Optional: consolidate `tv` canvas with phone `MandazaCanvas` after release.

## Ambient Time

Use Ambient Time only for **sideload practice** on Fire Stick while MandazaTV Fire is finished. Do not block MandazaTV store work on Ambient Time feature development.

## Amazon staging status

- Listing copy/icons: `tv/amazon-listing/`; screenshots are placeholders from
  tvOS and must be replaced with current Fire captures.
- In-app banner: real Top Shelf–derived PNG
- Signed release: retained `tv/dist/release/MandazaTV-1.3.0-release.apk` is stale
  and must be rebuilt.
- Device smoke: physical AFTTI43 Fire TV installed/launched and interactively
  exercised on 2026-08-09; long-run gates remain open.

See [AMAZON-RELEASE.md](AMAZON-RELEASE.md).
