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

Build with the existing release toolkit's `with-signing --profile mandaza`
and `MANDAZA_DISTRIBUTION=amazon scripts/stage-android-release.sh`.
The build writes signed artifacts and checksums under `dist/android/amazon/v1.3.6/`.
Keep passwords and private keys out of logs and release evidence.

The September 1.3.3 sheet is retained at
[AMAZON-TABLET-EVIDENCE.md](AMAZON-TABLET-EVIDENCE.md). The newer Pixel tests
cover a separate F-Droid artifact and do not close these Fire-device checks.

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
