---
title: Mandaza — Privacy Policy
---

# Mandaza — Privacy Policy

_Last updated: 2026-07-22_

Mandaza does not collect, store, or transmit any personal data. The app
runs entirely on your device. It makes no network requests, includes no
analytics SDKs, and does not create an account.

## Mandaza for iPhone and iPad (iOS)

Mandaza requests **write access to your Photo Library** only when you choose to
save an image. If you enable Music responsivity, it also requests microphone
access to derive live sound level and beat information in memory. Audio is
never recorded, stored, uploaded, or shared.

The app's bundled WidgetKit extension renders mandala images using the
same on-device engine. No data leaves your device through widgets.

## Mandaza for Android

The Google Play build creates procedural art entirely on-device and makes no
network requests. It requests microphone access only when you enable Music
responsivity. Mandaza reduces microphone input to a live sound-level value in
memory and immediately discards the audio samples. Nothing gets recorded,
stored, uploaded, or shared.

When you choose Save, Mandaza writes the generated image to the device's media
library. Settings, favorites, and recent designs remain on the device. The app
contains no account, advertising, analytics, tracking, or third-party data
collection SDK.

The separately distributed Android build may check Luke Steuber's public
Mandaza release catalog for updates. That check sends only the ordinary
technical information inherent in an HTTPS request and is not present in the
Google Play build.

## Mandaza for Apple TV (tvOS)

**Mandaza for Apple TV** is the same product experience on tvOS: procedural
art and optional Zen overlays, entirely on-device. The Apple TV app does **not**
request Photos access (saving to Photos is not offered on tvOS). It does not
use the camera or microphone.

Settings and preferences are stored locally on Apple TV using standard system
preferences. Although the signed app retains the Mandaza App Group entitlement,
the current tvOS code does not read from or write to the shared container. The
entitlement itself does not transmit data.

## Mandaza for Apple Watch (watchOS)

The watch app renders procedural art locally. If Music Mode is enabled, its
microphone processing follows the same in-memory, never-recorded policy.
Mandaza uses Apple's WatchConnectivity framework to exchange selected settings
and user-requested snapshots directly between the paired iPhone and watch; this
data is not sent to Luke Steuber or third parties.

For questions: [luke@lukesteuber.com](mailto:luke@lukesteuber.com)

The Mandaza source is available at
[github.com/lukeslp/mandaza](https://github.com/lukeslp/mandaza).
