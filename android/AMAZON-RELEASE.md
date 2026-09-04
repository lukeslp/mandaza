# Amazon Appstore release tracks

Mandaza uses independent Amazon packages, listings, artifacts, and evidence for
Fire TV and Fire tablets. Never attach one binary to the other record.

## MandazaTV — live Fire TV record

| Field | Value |
|---|---|
| Title / SKU | Mandaza / `app.mandaza.tv` |
| Package | `app.mandaza.tv` |
| Version | `1.3.1 (20301)` |
| Artifact | `tv/dist/release/MandazaTV-1.3.1-release.apk` |
| APK SHA-256 | `1dfbfeee87d3a87cee31f68c150d96f58a1a0134b4c9350f799139ed44499023` |
| Portal app id | `amzn1.devportal.mobileapp.0130d2b1a19447bb9d6367e7741d1e3b` |
| Portal release id | `amzn1.devportal.apprelease.c42c655564a64765b02f0124762f9c6f` |
| Console state | Live, reverified 2026-09-04 |

The repository’s signed candidate passed D-pad, lifecycle, offline, and
30-minute stability gates on Amazon AFTTI43 in August. A final store-delivered
install and Apps-row banner check remains deliberately open; local ADB evidence
does not substitute for the Amazon-delivered package.

Build or restage the immutable TV artifact only for independent verification:

```sh
cd /Users/luke/workspace/android-release-toolkit
scripts/android-release with-signing --profile mandaza -- \
  /Users/luke/workspace/mandaza-ios/android/tv/scripts/stage-release.sh
```

Listing copy, art, capture metadata, and exact screenshot roles live under
`tv/amazon-listing/`.

## Mandaza — Fire tablet candidate

| Field | Value |
|---|---|
| Package | `app.mandaza.android` |
| Version | `1.3.3 (10308)` |
| Flavor | `amazonRelease` |
| Device family | Fire tablets only |
| Console state | No record as of 2026-09-04 |
| Privacy | No account, analytics, ads, or app networking |
| Microphone | Optional local music responsiveness; audio is never stored or transmitted |

The Amazon flavor has no direct updater, no Internet permission, and no Google
Play Review dependency. Its native renderer remains representative of the
public Mandaza experience.

```sh
cd /Users/luke/workspace/android-release-toolkit
MANDAZA_DISTRIBUTION=amazon scripts/android-release with-signing \
  --profile mandaza -- /Users/luke/workspace/mandaza-ios/scripts/stage-android-release.sh
```

The stage script runs unit tests and release lint, verifies APK/AAB signatures,
asserts package/version identity, rejects Internet permission and Google Play
libraries, and writes immutable checksums under `dist/android/amazon/v1.3.3/`.
Complete the exact signed-device gate in `android/AMAZON-TABLET-EVIDENCE.md`
before preparing a listing. Tablet copy and asset provenance are tracked in
`android/amazon-listing/ASSET-MAP.md`; Fire TV assets remain separate under
`android/tv/amazon-listing/`.

## Human console checkpoints

- For the live TV record, install the Amazon-delivered version and record its
  version, package, Apps-row banner, signature lineage, and smoke result.
- For the tablet track, create a separate standard Amazon app only after the
  signed 10308 device gate passes. Confirm Fire-tablet-only targeting, disclose
  the optional microphone behavior, apply the listing pack, and submit.

No repository script logs into or publishes through Amazon.
