# 1.3 screenshot staging — provenance and status

Captured 2026-07-08 during the Music Mode + Apple Watch control feature work, via
paired iPhone 17 Pro + Apple Watch Ultra 3 simulators (real WatchConnectivity
pairing, confirmed via device logs — not faked).

| File | Size | Status |
|---|---|---|
| `01_iphone_music_mode.png` | 1206×2622 | **Needs recapture** — iPhone 17 Pro native res, not an ASC-accepted size. Recapture on iPhone 17 Pro Max sim (1320×2868) using `SIMCTL_CHILD_MANDAZA_MUSIC_DEMO=1` + `SIMCTL_CHILD_MANDAZA_PALETTE=<id>` per `reference/screenshots.md`. |
| `02_iphone_apple_watch_settings.png` | 1206×2622 | Same — needs recapture at 1320×2868. Shows real "Watch connected." status. |
| `03_watch_face.png` | 422×514 | **ASC-ready** (Apple Watch Ultra native size matches spec exactly). |
| `04_watch_settings_sheet.png` | 422×514 | **ASC-ready.** Shows real "Synced from iPhone" status with elapsed time — proof the sync path works, not a mockup. |

## Still to capture
- iPhone: Digital-Crown-palette-cycling equivalent isn't an iPhone shot (watch-only) — see Apple Watch set below.
- Watch: tap-to-regenerate transition frame, Digital Crown palette cycling frame, and a genuine side-by-side "Send to Watch" moment (two synced photos, phone + watch, same design) — the copy draft's screenshot plan (`APP_STORE_PACK.md` pending section) calls for 5-6 watch frames total; only 2 are captured here.
- tvOS: unchanged in 1.3 — reuse existing screenshots, no recapture needed.

## Recapture command reference
See `~/.claude/skills/app-store-ship/reference/screenshots.md` for the exact
capture loop, DEBUG env-var technique, and `asc_ship.py screenshots` upload
step. Do not upload the 1206×2622 files as-is — they'll fail ASC's size
validation.
