# Amazon Appstore — MandazaTV (Fire TV)

**Priority:** Fire TV living room. Fire tablet is second and not required for this submission.

## Package

| | |
|---|---|
| Application ID | `app.mandaza.tv` |
| Module | `:tv` |
| Version | `1.3.1 (20301)` |
| Privacy | https://mandaza.app/privacy.html |
| Listing pack | `tv/amazon-listing/` |

## Staged artifacts

After a signed release build:

```
android/tv/dist/release/
  MandazaTV-<version>-release.apk
  SHA256SUMS.txt
  PROVENANCE.txt
```

Listing art and paste copy live in `tv/amazon-listing/` (see `ASSET-MAP.md`).

## Build signed release

```sh
cd /Users/luke/workspace/android-release-toolkit
scripts/android-release with-signing --profile mandaza -- \
  /Users/luke/workspace/mandaza-ios/android/tv/scripts/stage-release.sh
```

Or with env already loaded:

```sh
cd /Users/luke/workspace/mandaza-ios/android
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export ANDROID_HOME="$HOME/Library/Android/sdk"
./tv/scripts/stage-release.sh
```

## Device gate (Fire TV / Stick / Cube)

Record model + Fire OS version, then verify:

1. Install APK without network if possible
2. App appears in Fire TV **Apps** row with banner
3. D-pad: navigate New / Zen / Tune, move between Tune rows, and activate each item
4. With controls hidden, Select/Play generates and a direction restores controls
5. Back leaves Zen, closes Tune, then toggles the primary rail
6. Clock toggle works; Void/Paper theme and palette controls work
7. Confirm `wm size` keeps the app override at 1920×1080 on 4K Fire panels
8. Home → resume; sleep/wake; ~30+ min run without crash

Capture at least three device screenshots if replacing listing art. Current
requirements and capture metadata are recorded in
`tv/amazon-listing/ASSET-MAP.md` and `SCREENSHOT-METADATA.md`.

### Current device evidence — 2026-08-09

- AFTTI43 (`brandenburg`), Fire OS 7 / Android 9, physical 4K panel with
  Amazon/Android 1920×1080 framebuffer override.
- Signed `1.3.1 (20301)` APK installed and launched over ADB at
  `192.168.0.120:5555`; signature, manifest version, and staged SHA-256 verified.
- New / Zen / Tune navigation and current glow-free renderer captured at
  1920×1080.
- The bounded render loop stopped at 338 rendered frames and remained there
  during later idle samples. Reveal cadence measured median 22 ms / p90 31 ms.
- Five current 1920×1080 physical-device listing screenshots captured from that
  exact signed release.
- Open: Home/resume, sleep/wake, and 30+ minute run.

## Console sequence (human only)

1. Amazon Developer Console → create app **MandazaTV** (or update)
2. Upload signed APK; confirm **Fire TV** device family
3. Paste `tv/amazon-listing/amazon.txt`
4. Upload icons, background, five screenshots per `ASSET-MAP.md`
5. Content rating / audience / privacy URL
6. Submit only after device gate notes are attached

This repo never logs into Amazon for you.

## Not this track

- Phone Mandaza (`app.mandaza.android`) — separate product
- Ambient Time — optional sideload practice only
