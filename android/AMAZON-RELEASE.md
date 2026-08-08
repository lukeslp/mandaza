# Amazon Appstore — MandazaTV (Fire TV)

**Priority:** Fire TV living room. Fire tablet is second and not required for this submission.

## Package

| | |
|---|---|
| Application ID | `app.mandaza.tv` |
| Module | `:tv` |
| Version code | `20300` (scaffold; bump on each store upload) |
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

## Device gate (Fire Stick / Cube)

Record model + Fire OS version, then verify:

1. Install APK without network if possible
2. App appears in Fire TV **Apps** row with banner
3. D-pad: Select/Play → new pattern; ←/→ palette; Back toggles dock
4. Dock auto-hides; ambient canvas remains focused
5. Clock toggle works; theme Void/Paper works
6. Home → resume; sleep/wake; ~30+ min run without crash

Capture at least three device screenshots if replacing listing art.

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
