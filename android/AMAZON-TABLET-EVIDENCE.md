# Mandaza Fire tablet evidence

Target artifact: Mandaza 1.3.3 (10307), package `app.mandaza.android`,
`amazonRelease` flavor.

## Automated release gate

- [x] Core and Amazon unit tests pass.
- [x] Amazon release lint passes.
- [x] APK and AAB signatures verify with Mandaza's established certificate.
- [x] Checksums are recorded for both artifacts.
- [ ] APK has version code 10307, no Internet permission, and no Google Play
  dependency.

## Superseded build 10306 evidence — 2026-09-04

- APK: `dist/android/amazon/v1.3.3/Mandaza-1.3.3-amazon.apk`
- APK SHA-256: `1bae87e0ddac41f57a269a0bf750b05160c1d5843f39fa8b04430b3a134fded9`
- AAB SHA-256: `d42546020ac6140e33ab8fc1770bc32d1a124f7bcbd679dee8779759d86a6bfc`
- Certificate SHA-256: `de02c811472ce4808b30cae0abf7a13e72b38013c0bbecfbcfe590523ef8077a`
- Manifest: touchscreen required, microphone optional, ordinary launcher only.

Build 10306 is not a submission candidate. On a fresh Fire OS 8 install,
entering Zen immediately requested microphone access because music
responsiveness defaulted on. The fix defaults that optional feature off and
advances the Amazon version code to 10307. No 10306 device screenshot or
stability result transfers to the rebuilt bytes.

Supplemental non-Fire 10306 smoke, 2026-09-04: the exact APK installed and launched
on a Pixel 9a (Android 16), rendered the native canvas and Tune sheet in portrait
and landscape, resumed after Home with the same process, and produced no crash
buffer entry. This catches general Android regressions but does not satisfy any
Fire-specific checkbox below.

## Signed Fire-device gate

Record the exact APK hash, signing certificate, tablet model, Fire OS version,
and test date. Then verify:

- [ ] Cold launch and native renderer with networking unavailable.
- [ ] Tap, Back, rotation, Home/resume, and sleep/wake.
- [ ] New pattern, Zen, Tune/settings, palette, Void/Paper, and PNG export.
- [ ] Microphone permission is requested only when music responsiveness is
  enabled; denial leaves the renderer usable; audio is not saved or sent.
- [ ] VoiceView labels, focus order, state announcements, font scaling, and
  touch targets.
- [ ] 60-minute render session has no crash, ANR, persistent frame degradation,
  or runaway memory growth.

Do not create the Amazon listing until the signed artifact—not a debug build—
passes this sheet.
