# Mandaza for Android and Wear OS

Native Jetpack Compose ports of Mandaza. The phone/tablet app and Pixel Watch
companion share a Kotlin implementation of the seeded loop engine, palettes,
and saved snapshot model. They do not use a WebView or require a server.

## Modules

- `core` — deterministic geometry engine, all twelve palettes, snapshot and collection models
- `app` — Android phone/tablet canvas, collections, Zen, parallax, music responsivity, settings, deep links, and PNG export
- `wear` — Wear OS canvas; tap for a new Mandaza, rotate the crown for palettes, long-press for guidance

Android parallax is available in both standard and Zen presentation. There are
no Android lock-screen widgets. The first Android release intentionally focuses
on the base app and watch companion; Home Screen widgets and phone-to-watch
sync remain follow-up work.

The phone app checks the public Drummer downloads catalog once per day. When
the Android version in `https://dr.eamer.dev/downloads/catalog.json` is newer,
it offers a dismissible link to the Mandaza download page. Publishing a new APK
through the Android release toolkit updates that catalog and activates the
prompt; no Play Store integration is required.

## Build and test

Use JDK 21 and Android SDK 36:

```sh
cd android
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export ANDROID_HOME="$HOME/Library/Android/sdk"
./gradlew :core:testDebugUnitTest :app:assembleDebug :wear:assembleDebug
```

Install on a connected Android phone:

```sh
./gradlew :app:installDebug
```

Install the companion on a connected Wear OS watch:

```sh
./gradlew :wear:installDebug
```

Release signing is deliberately not checked into this repository. Configure a
private Gradle signing configuration before producing Play Store bundles.
