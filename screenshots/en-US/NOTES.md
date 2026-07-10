# 1.3 screenshot staging — provenance and status

Hero cards and Watch face variants staged 2026-07-09 for Mandaza 1.3
(music responsivity, clock forms, tilt parallax, Watch companion).

| File | Size | Status |
|---|---|---|
| `01_iphone_mandalas.png` | 1320×2868 | **ASC-ready** — iPhone 6.9" hero. |
| `02_iphone_music.png` | 1320×2868 | **ASC-ready** — music-reactive Zen. |
| `03_iphone_clock.png` | 1320×2868 | **ASC-ready** — digital clock form. |
| `04_iphone_stacked.png` | 1320×2868 | **ASC-ready** — stacked clock form. |
| `05_iphone_calm.png` | 1320×2868 | **ASC-ready** — calm / editorial beat. |
| `watch_1_aurora.png` | 422×514 | **ASC-ready** — Watch Ultra face (Aurora). |
| `watch_2_cyberpunk.png` | 422×514 | **ASC-ready** — Watch Ultra face (Cyberpunk). |
| `watch_3_vaporwave.png` | 422×514 | **ASC-ready** — Watch Ultra face (Vaporwave). |
| `watch_4_ember.png` | 422×514 | **ASC-ready** — Watch Ultra face (Ember). |

## Optional later frames
- Watch: tap-to-regenerate transition, Digital Crown palette cycle, side-by-side Send to Watch.
- iPhone: Settings > Apple Watch pairing status (if ASC wants a sixth phone slot).
- tvOS: unchanged in 1.3 — reuse existing screenshots.

## Capture hooks
DEBUG env vars (`MANDAZA_MUSIC_DEMO`, palette / clock-form hooks) live in
`MandazaCore/ScreenshotSupport.swift`. See
`~/.claude/skills/app-store-ship/reference/screenshots.md` for the capture loop
and `asc_ship.py screenshots` upload step.
