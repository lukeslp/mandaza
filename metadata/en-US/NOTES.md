# 1.3 metadata staging

Prepared for the Mandaza 1.3 App Store update (music responsivity, clock
forms, tilt parallax, Watch companion). Ready for
`asc_ship.py metadata com.lukesteuber.mandaza IOS 1.3 metadata/en-US`
per `~/.claude/skills/app-store-ship/SKILL.md`.

**Not yet pushed to App Store Connect.** This repo uses `asc_ship.py`
(ASC REST API) rather than `fastlane deliver` — see
`~/.claude/skills/app-store-ship/reference/gotchas.md` #8: fastlane's
`deliver` crashes non-interactively, so this project's pipeline has always
gone through the API script directly. `description.txt` / `keywords.txt` /
`promotional_text.txt` / `release_notes.txt` here are exactly what that
script expects.

tvOS now ships under the shared `com.lukesteuber.mandaza` app record. Add
Apple TV platform screenshots/metadata on that record when staging tvOS assets.

Before running the ship pipeline for real:
1. Confirm iPhone 1320×2868 heroes + Watch Ultra faces in
   `../../screenshots/en-US/` (see `NOTES.md` there — currently ASC-ready).
2. Confirm with Luke whether this is a stage-only pass or a submit-for-review
   pass — the skill requires that boundary be explicit before touching ASC.
