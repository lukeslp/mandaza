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
- [ ] Freeze source, verify signed APK/AAB and record 10314's issued hashes
- [ ] Upgrade on Fire in place; verify installed bytes, identity and retained look
- [ ] Repeat denial, Home/resume and cold launch without a new prompt
- [ ] Verify clock boundaries, portrait/landscape, large text and reduced motion
- [ ] Check offline launch, Back, export and applicable touch/keyboard paths
- [ ] Check VoiceView names, states, focus and common tasks; retain separate
  human spoken-output acceptance
- [ ] Complete a fresh one-hour run for these signed bytes
- [ ] Capture final-build listing scenes and finish transparent icons
- [ ] Review/publish Fire privacy coverage, tablet model selections and metadata
- [ ] Complete the store checkpoint and Amazon-delivered smoke/upgrade check

10312 completed its bounded Paper Zen hour with stable foreground/process and
no sustained memory growth. 10313's large-text/rotation and live reduced-motion
checks pass; neither result transfers the full gate to 10314. The Fire has a
secure lock, so sleep/wake awaits the owner's return rather than locking it
while unattended. No new Pixel test is claimed.

The public F-Droid source tag and upstream-signed 10311 APK remain unchanged.
Carry any later public-source/catalog update through its own signing,
reproducibility, device and third-party-write approval checkpoints.
