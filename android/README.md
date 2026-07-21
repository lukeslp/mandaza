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
- `wear` — experimental Wear OS source; not built or distributed as part of the supported release

Android parallax is available in both standard and Zen presentation. There are
no Android lock-screen widgets. The supported Android release focuses on the
phone/tablet app; Home Screen widgets remain follow-up work.

The `direct` flavor checks the public Drummer downloads catalog once per day
and links to the Mandaza download page when a newer version is available. The
`play` flavor contains no direct updater or network permission and relies on
Google Play for updates.

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

Build and stage a signed direct-distribution release through the shared release
identity:

```sh
cd /Users/luke/workspace/android-release-toolkit
scripts/android-release with-signing --profile mandaza -- \
  /Users/luke/workspace/mandaza-ios/scripts/stage-android-release.sh
```

Set `MANDAZA_DISTRIBUTION=play` to stage the Google Play flavor. The direct
release uses version code `10303`; the Play release uses version code `10304`.

Release signing material remains outside the repository and its password stays
in macOS Keychain. Google Play login, upload, and submission remain manual.
