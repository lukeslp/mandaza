# Mandaza Fire tablet evidence

Target artifact: Mandaza 1.3.3 (10306), package `app.mandaza.android`,
`amazonRelease` flavor.

## Automated release gate

- [ ] Core and Amazon unit tests pass.
- [ ] Amazon release lint passes.
- [ ] APK and AAB signatures verify with Mandaza's established certificate.
- [ ] Checksums are recorded for both artifacts.
- [ ] APK has version code 10306, no Internet permission, and no Google Play
  dependency.

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
