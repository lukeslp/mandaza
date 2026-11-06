# Mandaza 1.3.8 for Fire tablets

Private replacement for [1.3.7 (10313)](AMAZON-1.3.7-READINESS.md), prepared
November 5, 2026. No Amazon upload or public app release has occurred.

The exact-10313 Fire test reproduced a denial problem: Music responsivity
stayed enabled after microphone denial, so the explanation returned after a
hot Home/resume. The app now stops the audio monitor, disables Music
responsivity and saves that state when access is denied. The artwork and
clock remain available, and enabling the feature again is a deliberate choice.
The test preserves the Fire's pre-existing denied permission and user-fixed
flag; it does not clear production permission history or grant microphone access.

The clock also updates at the next wall-clock second or minute boundary.
The old fifteen-second minute-clock poll could briefly display the previous
minute beside the newer status-bar time. Boundary tests protect against both
late updates and a zero-delay loop at an exact boundary.

The candidate retains 10313's Paper Zen contrast, clock wrapping/spacing and
live system reduced-motion corrections. Its package is `app.mandaza.android`,
version 1.3.8 (10314), minimum API 24 and target API 36. The existing signer
and unchanged license/notice bundle remain required. The preparation script
stages only Amazon; the other flavors need their own raised codes and review.

## Evidence and remaining checks

The clock regression tests first failed in three boundary cases. The stronger
microphone test also failed before the fix: its switch remained On after denial.
Private red/green evidence is under
`/Volumes/Galactus/android-fire-releases/20261105/mandaza-10314-regression/`.

- [x] Sixteen core/Amazon JVM tests pass; release lint has no errors and
  22 warnings; all nine debug acceptance journeys pass in the isolated
  API 36.1 emulator
- [x] Freeze source, verify signed APK/AAB and record 10314's issued hashes
- [x] Upgrade on Fire in place; verify installed bytes, identity and retained look
- [x] Repeat denial, Home/resume and cold launch without a new prompt
- [x] Verify clock boundaries, portrait/landscape, large text and reduced motion
- [x] Check offline launch, Back, PNG export and keyboard access to Tune
- [ ] Check VoiceView names, states, focus and common tasks; retain separate
  human spoken-output acceptance
- [ ] Check optional live sound response and motion pause/resume with owner-
  approved microphone access; the existing user-fixed denial was preserved
- [x] Complete a fresh one-hour run for these signed bytes
- [x] Capture five final-build Fire scenes with captions and artifact hashes
- [ ] Finish transparent icon exports and destination review of the media
- [ ] Review/publish Fire privacy coverage, tablet model selections and metadata
- [ ] Complete the store checkpoint and Amazon-delivered smoke/upgrade check

10312 completed its bounded Paper Zen hour with stable foreground/process and
no sustained memory growth. 10313's large-text/rotation and live reduced-motion
checks pass; neither result transfers the full gate to 10314. The Fire has a
secure lock, so sleep/wake awaits the owner's return rather than locking it
while unattended. No new Pixel test is claimed.

## Signed candidate and Fire checkpoint

The source pin is `ef7100fd6c117783f1627ed7811e1cfec3ea95b4`.
The APK SHA-256 is
`515a62efc20a3161a4ae25ff2cd5c9a42033d80d2f02f5018c470aa88b48e645`;
the AAB SHA-256 is
`f2de6bf8f4230b47f352dc0d49e20eadb8d4f2ec41e3f7cedf7d64ff643c66e7`.
Both retain certificate SHA-256
`de02c811472ce4808b30cae0abf7a13e72b38013c0bbecfbcfe590523ef8077a`.
All eleven notices and four native-library hashes match the reviewed baseline.
The next different phone/tablet artifact needs code 10315 or higher.

The exact APK upgraded the Fire HD 8 from 10313 without uninstalling or
resetting it. Installed bytes, UID and first-install time match the expected
upgrade. The existing artwork and clock reopened. Microphone denial now leaves
Music responsivity Off, including after hot Home/resume and cold launch; the
existing denied permission and user-fixed flag were preserved.

At system font scale 2, the editor controls and clock remain visible in both
orientations. The first rotation write reverted before a landscape capture;
a second write produced the actual landscape check. This was not counted as
an app failure. With system animation scales at zero, the foreground frame
counter stayed unchanged over four seconds. All tested settings, including
Wi-Fi after the offline cold launch, were restored to their starting values.

Tab reaches Tune, Enter opens it, and Back returns to the editor. Save produced
a readable 1440 × 2560 PNG in Pictures/Mandaza. Only that new test export was
pulled for inspection. The digital clock matched the device minute in a
snapshot just after the next boundary; this does not measure subsecond latency.

VoiceView bound successfully with touch exploration enabled, and screenshots
show focus on the canvas and Exit Zen. Injected gestures and keys did not
reliably complete accessibility-focused actions, so neither task completion
nor spoken feedback is marked passed. No app-failure conclusion follows from
that input limitation. VoiceView and its derived settings are restored.

The exact-10314 Paper Zen hour completed from 19:20:50 to 20:20:50 Pacific:
61 samples over 3600.67 seconds, with the same awake foreground process.
PSS ranged from 171,514 to 205,957 KB. The six full ten-sample means range
from 178,925 to 179,990 KB, with no sustained upward trend; the final single
sample is separate. Graphics memory ranged from 104,924 to 134,492 KB.
The final thermal status was zero. Retained own-process crash and own-package
crash/ANR buffers had no entries. The final frame shows the advancing clock,
and the installed APK hash still matches. This covers this Paper Zen configuration
with glow and sound response Off. The earlier 10312 hour remains separate.
Private receipts,
screenshots, settings comparisons and the new export are under
`/Volumes/Galactus/android-fire-releases/20261105/fire-device-checks/mandaza-10314-interactive/`.
The one-hour samples are in the adjacent `mandaza-10314-stability/` directory.

The public F-Droid source tag and upstream-signed 10311 APK remain unchanged.
Carry any later public-source/catalog update through its own signing,
reproducibility, device and third-party-write approval checkpoints.
