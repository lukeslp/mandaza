# Mandaza 1.3.7 for Fire tablets

Private follow-up to the [10312 candidate](AMAZON-1.3.6-READINESS.md), prepared
November 5, 2026. No Amazon upload or public release has occurred.

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
- Amazon debug assembly passes; release lint is being rechecked after removing
  a newly introduced modifier-order warning

The new source requires a new signed APK/AAB and its own exact-byte checks.
The 10312 observation remains baseline evidence for 10312 only.

## Before submission

- [ ] Verify signed APK/AAB, signer, manifest, notices and native-library hashes
- [ ] Record 10313's issued hashes in the release version ledger
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
