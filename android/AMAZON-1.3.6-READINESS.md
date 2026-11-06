# Mandaza 1.3.6 for Fire tablets

Prepared November 5, 2026, on the private
`codex/mandaza-amazon-20261105` branch. No Amazon upload or submission has occurred.

The recovered Amazon 1.3.3 (10308) APK matches the September Fire-device evidence,
but lacks the eleven-file notice bundle added during the recent provenance
review. This candidate moves that bundle into the shared Android assets so
every phone/tablet flavor includes it, with the original notice text preserved.
The published F-Droid source tag and signed release remain unchanged.

## Candidate identity

- Package: `app.mandaza.android`
- Version: 1.3.6 (10312), `amazonRelease`
- Minimum API: 24; target API: 36
- Existing Mandaza release signer; no new key
- Fire tablets only; Fire TV remains a separate package
- No Internet permission or Google Play Review dependency
- Optional microphone responsiveness remains off until enabled

## Checks

- [x] Core and Amazon unit tests: 12 pass, with no failures or skips
- [x] Amazon release lint: no errors, 22 warnings
- [x] Signed APK and AAB verification, package/version and signer checks
- [x] Exact notice bytes, reviewed native libraries and runtime dependency graph
- [ ] Fresh signed Fire-device installation and upgrade/data-retention checks
- [ ] Touch, rotation, Back, offline, Home/resume and sleep/wake
- [ ] VoiceView, text scaling, reduced motion and microphone denial
- [ ] One-hour stability run
- [ ] Fresh Fire screenshots, icon exports and listing copy review
- [ ] Current Amazon record, supported-model filtering and listing review
- [ ] Upload/submission result and Amazon-delivered smoke check

The [Amazon-specific listing packet](amazon-listing/1.3.6/README.md) now has
title, descriptions, five feature bullets, reviewer notes and a draft privacy
addendum, checked against current official asset/text requirements. It remains
local. Chrome confirms the five existing Amazon listings are live; the one
named Mandaza is `app.mandaza.tv` 1.3.1 (20301), not this tablet package.
The public privacy page still covers Apple platforms only and needs the
reviewed Android/Amazon coverage before submission. New Fire screenshots and
Amazon icon exports remain open.

Build with the existing release toolkit's `with-signing --profile mandaza`
and `MANDAZA_DISTRIBUTION=amazon scripts/stage-android-release.sh`.
The build writes signed artifacts and checksums under `dist/android/amazon/v1.3.6/`.
Keep passwords and private keys out of logs and release evidence.

The September 1.3.3 sheet is retained at
[AMAZON-TABLET-EVIDENCE.md](AMAZON-TABLET-EVIDENCE.md). The newer Pixel tests
cover a separate F-Droid artifact and do not close these Fire-device checks.

The Galaxy Flip media handoff covers the older public 1.3.5 (10310) APK in
wide-cover mode. It does not validate this Amazon candidate or the F-Droid
1.3.6 APK. Full-panel camera handling remains unverified; no dual-fold test
hardware is available. Keep those QA images historical and capture this exact
Amazon build on the intended Fire tablet before using images in its listing.

## Local validation

Both signed packages contain all eleven notices with the reviewed source bytes.
All four native library hashes match the prior provenance inventory. The resolved
Amazon and F-Droid runtime selections are identical: 96 external coordinates
and 61 unique selected binary artifacts, all with reviewed hashes. The inventory
also records two aggregate Lifecycle AARs that neither configuration selected;
the raw artifact view repeats one selected entry. No Google Play, Play Services,
ML Kit or Firebase classes were found in the Amazon APK's DEX report.

A separate unsigned F-Droid assembly confirms the shared asset move preserves
its notice bundle. The build, signatures, dependency selection and verification
receipts are under `/Volumes/Galactus/android-fire-releases/20261105/`.
These checks establish a local candidate, not Fire-device or store acceptance.

## Fire installation checkpoint, November 5

The exact signed 10312 APK upgrades the Fire HD 8 (`KFRASWI`), Fire OS 8.3.3.8 /
API 30, from Amazon 10308 in place. The pulled installed APK matches the candidate
hash. The signer, UID and first-install record are preserved; no uninstall,
reset, downgrade or bulk permission grant was used. Individual saved items were
not extracted, so this does not close the full saved-state acceptance check.

The native mirror's pointer did not reliably select intended Fire controls.
Luke opened the tablet edition and authorized ADB control for the Fire tests,
including temporary VoiceView/text/animation settings with restoration. The
mirror was closed. The uninterrupted observation began at 17:02:38 Pacific;
its 14-minute checkpoint retained awake foreground and the same process, with
PSS between 148,693 and 177,303 KB. The hour has not yet completed. No
accessibility/display preference has been changed yet.

The exact-10312 screenshot also exposes a contrast issue in Paper Zen mode.
`ZenOverlay` fixes the Exit Zen icon tint at `#F5F0E8` against a `#F1E6CF`
canvas, about 1.09:1 contrast over blank ground. Its clock text is about 2.84:1
over the blank ground after the 38% black scrim. Correct the controls before
release and repeat the visual checks. Do not replace 10312 with different bytes;
a correction requires a new version code, at least 10313, and fresh device
evidence. The published F-Droid tag and signed APK remain unchanged.

Existing Amazon icon files are correctly sized but opaque. They remain
references, not completed exports under Amazon's current transparent-PNG
requirement. Touch, lifecycle, microphone denial, VoiceView, text scaling,
reduced motion and fresh listing scenes remain open.

Private receipts:
`/Volumes/Galactus/android-fire-releases/20261105/fire-device-checks/`.
