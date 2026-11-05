# Mandaza for Android and Wear OS

Native Jetpack Compose ports of Mandaza. The phone/tablet app is the supported
Android release. It does not use a WebView or require a server. Experimental
Wear OS source remains in the repository but is outside the release scope.

The phone/tablet application ID is `app.mandaza.android`. Kotlin source keeps
the established `com.lukesteuber.mandaza` namespace, and the experimental Wear
OS application keeps its independent `com.lukesteuber.mandaza.wear` identity.

## Modules

- `core` — deterministic geometry engine, all twelve palettes, snapshot and collection models
- `app` — Android phone/tablet canvas, collections, Zen, parallax, music responsivity, settings, deep links, and PNG export
- `tv` — **MandazaTV for Fire TV / Android TV** (`app.mandaza.tv`, Leanback). See [FIRE-TV.md](FIRE-TV.md).
- `wear` — experimental Wear OS source; not built or distributed as part of the supported release

Android parallax is available in both standard and Zen presentation. There are
no Android lock-screen widgets. The supported Android release focuses on the
phone/tablet app; Home Screen widgets remain follow-up work.

The `direct` flavor checks the public Drummer downloads catalog once per day
and links to the Mandaza download page when a newer version is available. The
`play` and `amazon` flavors contain no direct updater or network permission and
rely on their stores for updates. Only `play` links Google Play Review.

The published `fdroid` release has no direct updater, Google Play Review
dependency or Internet permission. Version 1.3.6 (10311) uses the established
direct signer and has now been installed over 1.3.5 on both Pixels without an
uninstall or reset. The separate review-app functional tests and the exact-release
upgrade/launch checks remain distinct evidence. Official F-Droid acceptance is
still pending.

New phone codes must exceed every issued code across direct, Play, Amazon and
F-Droid, including private candidates. The release toolkit tracks 10312 as the
current high-water mark; a new build needs at least 10313. Exact known artifacts
can be staged again unchanged. `scripts/stage-android-release.sh` checks the APK
against that ledger before staging. Different store signing keys and lower
version codes can still prevent switching channels in place.

## Build and test

Use JDK 21 and Android SDK 36:

```sh
cd android
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export ANDROID_HOME="$HOME/Library/Android/sdk"
./gradlew :core:testDebugUnitTest :app:assembleDebug
```

Install on a connected Android phone:

```sh
./gradlew :app:installDebug
```

Build MandazaTV (Fire TV / leanback):

```sh
./gradlew :tv:assembleDebug
# adb install -r tv/build/outputs/apk/debug/tv-debug.apk
```

The physical Fire TV gate currently targets an AFTTI43 at a 1920×1080 Amazon
framebuffer override on its 4K panel. The TV renderer caps logical geometry at
1080p, disables glow and continuous idle pulsing, and stops invalidating the
canvas when its reveal completes. See [FIRE-TV.md](FIRE-TV.md) for current
device evidence and [AMAZON-RELEASE.md](AMAZON-RELEASE.md) for open gates.

Build and stage a signed direct-distribution release through the shared release
identity:

```sh
cd /Users/luke/workspace/android-release-toolkit
scripts/android-release with-signing --profile mandaza -- \
  /Users/luke/workspace/mandaza-ios/scripts/stage-android-release.sh
```

Set `MANDAZA_DISTRIBUTION=play` or `MANDAZA_DISTRIBUTION=amazon` to stage the
corresponding store flavor. Direct uses version code `10310` and version name
`1.3.5`, Play uses `10305`, and the Fire-tablet candidate uses `10308`. Installed
direct copies compare their version name with `catalog.json`, so every direct
rebuild must raise the version name as well as the code. The live Fire TV app remains the
separate `app.mandaza.tv` package at `1.3.1 (20301)`.

Release signing material remains outside the repository and its password stays
in macOS Keychain. Google Play login, upload, and submission remain manual.
