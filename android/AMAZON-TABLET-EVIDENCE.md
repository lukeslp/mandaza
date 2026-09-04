# Mandaza Fire tablet evidence

Target artifact: Mandaza 1.3.3 (10308), package `app.mandaza.android`,
`amazonRelease` flavor.

## Automated release gate

- [x] Core and Amazon unit tests pass.
- [x] Amazon release lint passes.
- [x] APK and AAB signatures verify with Mandaza's established certificate.
- [x] Checksums are recorded for both artifacts.
- [x] APK has version code 10308, no Internet permission, and no Google Play
  dependency.

Candidate identity, 2026-09-04:

- APK: `dist/android/amazon/v1.3.3/Mandaza-1.3.3-amazon.apk`
- APK SHA-256: `ff09ef6899592414f63ac4b3d2e4fedd660d0bbaa79691fb917eef635b0fd7ff`
- AAB SHA-256: `3ec446762c702b377e9fab3c257ece5b613cb0b78862ac53a6ebb9e40a71a470`
- Certificate SHA-256: `de02c811472ce4808b30cae0abf7a13e72b38013c0bbecfbcfe590523ef8077a`
- Manifest: touchscreen required, microphone optional, ordinary launcher only.

## Superseded build 10307 evidence — 2026-09-04

- APK SHA-256: `a054d0e8d9f1e71ee2931a482059678e67c4ad7271b6101a25bec28927181896`
- AAB SHA-256: `bd8f4d6ae743252bcf41def03b18dd26b2e9d6788da077dcd8dce32da37e623e`
- Certificate SHA-256: `de02c811472ce4808b30cae0abf7a13e72b38013c0bbecfbcfe590523ef8077a`
- Manifest: touchscreen required, microphone optional, ordinary launcher only.

Build 10307 corrected the fresh-install microphone regression and passed the
exact-binary install, renderer, interaction, permission-timing, rotation,
lifecycle, and PNG-export checks on Amazon KFRASWI. Its accessibility-tree
inspection then exposed unlabeled settings switches and sliders. The candidate
is superseded; its soak was stopped and its screenshots were discarded. Build
10308 adds explicit accessible names. No 10307 evidence transfers to the new
bytes.

## Superseded build 10306 evidence — 2026-09-04

- Staged APK pathname at the time of validation (subsequently reused by newer builds):
  `dist/android/amazon/v1.3.3/Mandaza-1.3.3-amazon.apk`
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

Test device: Amazon KFRASWI, Fire OS 8.0 / Android 11, build
`0030132734852`, serial `GVW3T505623706SG`, 2026-09-04. The APK pulled back
from the fresh install matched the candidate SHA-256 byte for byte and retained
the certificate above.

- [x] Cold launch and native renderer with networking unavailable.
- [x] Tap, Back, portrait/landscape, Home/resume, and sleep/wake. The process
  remained PID 3043 through the lifecycle checks.
- [x] New pattern, Zen, Tune/settings, palette, Void/Paper, and PNG export.
- [x] Microphone permission is requested only when music responsiveness is
  enabled; denial leaves the renderer usable; audio is not saved or sent.
- [x] VoiceView labels, focus order, state announcements, font scaling, and
  touch targets.
- [x] 60-minute render session has no crash, ANR, persistent frame degradation,
  or runaway memory growth.

The fresh-install regression check entered Zen with microphone access still
denied and observed no permission prompt. Turning music responsiveness on in
Tune did not prompt there; the system request appeared only after entering
Zen. Denial produced the documented local-only explanation and left the
renderer usable.

Fire OS VoiceView (`com.amazon.logan`) was enabled for the signed candidate and
reported itself bound with spoken, haptic, and audible feedback. Keyboard focus
walked the palette, labeled switches, sliders, and clock-form choices in logical
order while the device TTS engine synthesized every step; both visible and
scrolled Tune surfaces contained zero `NAF` nodes. The main surface remained
usable at font scale 1.3, and the 63-pixel switch and 107-pixel footer targets
remained intact. The device accessibility and font settings were restored.

Five 800 × 1280 Fire-tablet captures from the exact installed APK are recorded
in `android/amazon-listing/ASSET-MAP.md`. The uninterrupted render soak ran from
2026-09-04 21:07:06Z through 22:07:10Z with PID 3043 throughout, zero crash or
ANR records, and PSS samples of 171,419, 166,573, 171,300, 172,485, 175,792,
175,518, and 171,009 KB. The app remained the foreground activity and finished
slightly below its launch memory. Fire OS accessibility, font, rotation,
airplane-mode, and stay-awake settings were restored after testing.

Do not create the Amazon listing until the signed artifact—not a debug build—
passes this sheet.
