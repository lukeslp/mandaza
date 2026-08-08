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

## Remote model (v1 scaffold)

| Input | Action |
|---|---|
| Select / Enter / Play-Pause | New pattern |
| ← / → (when dock visible) | Cycle palette |
| Directional when dock hidden | Show dock |
| Back | Toggle dock (does not exit app) |
| Dock idle | Auto-hide after ~18s |

Clock overlay and Void/Paper theme toggles live in the dock.

## Still to do before Amazon submit

1. Real TV banner artwork (replace placeholder vector).
2. Device QA on Fire Stick/Cube (Apps row, D-pad, sleep/wake, long run).
3. Amazon listing pack (1280×720 icon, 1920×1080 screenshots, paste copy from `metadata/tvOS/`).
4. Signed release APK with version bump policy.
5. Optional: consolidate `tv` canvas with phone `MandazaCanvas`.

## Ambient Time

Use Ambient Time only for **sideload practice** on Fire Stick while MandazaTV Fire is finished. Do not block MandazaTV store work on Ambient Time feature development.

## Staged for Amazon (2026-08-08)

- Listing pack: `tv/amazon-listing/` (icons, 5 screenshots, `amazon.txt`)
- In-app banner: real Top Shelf–derived PNG
- Signed release: `tv/dist/release/MandazaTV-1.3.0-release.apk` (local; gitignored)
- Device smoke: installed/launched on Pixel 9a (not a Fire Stick — still run Fire Stick gate before submit)

See [AMAZON-RELEASE.md](AMAZON-RELEASE.md).
