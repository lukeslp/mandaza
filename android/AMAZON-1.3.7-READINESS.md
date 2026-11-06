# Mandaza 1.3.7 for Fire tablets

Private follow-up to the [10312 candidate](AMAZON-1.3.6-READINESS.md), prepared
November 5, 2026. No Amazon upload or public release has occurred.

The later exact-10313 Fire test reproduced a denial/resume problem: the
microphone explanation returned after a hot Home/resume because the denied
feature stayed enabled. Keep these signed bytes immutable and private. The
[1.3.8 (10314) correction](AMAZON-1.3.8-READINESS.md) also aligns clock updates
with wall-clock boundaries; it needs its own signed/device evidence.

The exact-10312 Fire capture exposed low contrast in Paper Zen mode. The
Exit Zen icon now has an opaque dark button, and the clock uses a darker
background. The clock also has room at the screen edges and centers wrapped
text. Stacked clock lines have spacing appropriate to their larger type.

The Android app now follows the system Remove animations setting while open.
It shows the complete pattern without an animated reveal or idle color pulse,
stops tilt sampling and suspends microphone-driven motion while reduced motion
is active. Changing this setting does not erase the user's stored motion or
music preferences. Artwork still responds to a deliberate New action.

Microphone copy now says that recordings are not saved or sent. The existing
implementation measures amplitude with `MediaRecorder`, directing encoded
output to `/dev/null`; it does not retain an audio file. No new permission or
network capability was added.

## Candidate identity and validation

- Package: `app.mandaza.android`, `amazonRelease`
- Version: 1.3.7 (10313), above the already issued 10312
- Minimum API 24, target API 36
- Existing release signer; no new key or data migration
- F-Droid's published tag, recipe pin and signed 10311 APK remain unchanged
- Twelve core/Amazon JVM tests pass, with no failures or skips
- Amazon debug assembly passes; release lint has no errors and 22 warnings
- Signed APK and AAB verify with the existing signer
- All eleven license/notice files match reviewed 10312 bytes in both packages
- All four native libraries match 10312; no checked Google DEX namespaces found

The signed APK SHA-256 is
`54a373a872045f34045362c25694044599642e9ea38d83c00cd3f592b0787c11`.
The AAB SHA-256 is
`76844b82475eb76899c1db5dcec2e767da9b046477b9b6c4990e847c67f66fd4`.
Both were built from source commit `ea185772b2024cdaed6ef3e2d6b5f12ffd60db3f`.
The signed files and verification receipt are retained privately in
`/Volumes/Galactus/android-fire-releases/20261105/staged/mandaza-amazon/1.3.7-10313/`.
The portfolio's issued-code ledger now reserves these exact 10313 hashes;
new Mandaza bytes need at least 10314.

The signed APK still needs its own exact-byte device checks.
The 10312 observation remains baseline evidence for 10312 only.

Nine debug acceptance journeys pass in an isolated API 36.1 tablet emulator:
the eight-test suite plus a separate 200% text journey across all three Paper
Zen clock forms. The motion test follows live system changes, compares still
artwork over 30 seconds, generates a new pattern deliberately and restores
normal motion. Digital, stacked and editorial QA captures were visually checked;
Exit Zen and clock text remain clear in this landscape emulator. The temporary
font and animation settings were restored, and the owned emulator was closed.
This does not close the Fire, portrait or signed-release-byte gates. Evidence is
in `mandaza-10313-emulator-checks/` under the dated private release root.

The preparation script stages only Amazon on this branch. The direct and Play
flavor codes still refer to historical releases and must be raised and reviewed
before those shared changes can be issued on another channel.

## Before submission

- [x] Verify signed APK/AAB, signer, manifest, notices and native-library hashes
- [x] Record 10313's issued hashes in the release version ledger
- [ ] Upgrade on Fire in place and verify installed bytes and retained state
- [ ] Check touch, all clock forms, Paper/dark contrast and 200% text
- [ ] Check live system reduced-motion changes and normal-motion restoration
- [ ] Check microphone denial, offline behavior, rotation, Back, Home/resume
  and sleep/wake
- [ ] Check VoiceView focus, names, selected states and reachable common tasks
- [ ] Complete a fresh one-hour observation for the new signed APK
- [ ] Capture three to ten different final-build Fire scenes and finish
  transparent icon exports with captions, hashes and provenance
- [ ] Integrate reviewed Fire privacy coverage into the public policy
- [ ] Review the separate tablet record and supported models
- [ ] Complete the human upload/submission and Amazon-delivered smoke checks

No Pixel result or TV install closes a Fire-tablet gate. The public F-Droid
source needs a separately reviewed follow-up if these Android corrections are
carried there; do not move the existing tag or silently change its release.
