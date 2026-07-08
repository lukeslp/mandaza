# 1.3 metadata staging

Prepared 2026-07-08 for the Mandaza 1.3 App Store update (Music Mode +
Apple Watch control). Ready for `asc_ship.py metadata com.lukesteuber.mandaza IOS 1.3 metadata/en-US`
per `~/.claude/skills/app-store-ship/SKILL.md`.

**Not yet pushed to App Store Connect.** This repo uses `asc_ship.py`
(ASC REST API) rather than `fastlane deliver` — see
`~/.claude/skills/app-store-ship/reference/gotchas.md` #8: fastlane's
`deliver` crashes non-interactively, so this project's pipeline has always
gone through the API script directly. `metadata.txt`/`keywords.txt`/
`promotional_text.txt`/`release_notes.txt` here are exactly what that
script expects.

tvOS metadata is unchanged in 1.3 — no `metadata/en-US` update needed for
`com.lukesteuber.mandaza.tv`.

Before running the ship pipeline for real:
1. Recapture the two iPhone screenshots at an ASC-accepted size (see
   `../../screenshots/en-US/NOTES.md`).
2. Confirm with Luke whether this is a stage-only pass or a submit-for-review
   pass — the skill requires that boundary be explicit before touching ASC.
