# Mandaza — project plan

## Current objectives

- **iOS / iPadOS:** Ship on-device generative mandalas, Home Screen / StandBy widgets, Photos export, `mandaza://` deep links, Zen + music responsivity + tilt.
- **watchOS:** Live companion face with mirror sync and Send to Watch.
- **tvOS:** Ship a fullscreen ambient companion app with a quick-control rail, compact “controls hidden” hint, larger Zen clock typography, and a tvOS-safe collapsible Zen section (no `DisclosureGroup`); `UILaunchScreen` uses `LaunchSplashTV` (iOS uses `LaunchSplashIOS`) to hard-bust stale launch-screen caches.
- **Shared:** Single `MandazaCore` engine and App Group–backed settings; `project.yml` + XcodeGen as the project source of truth. Brand refreshes: `scripts/apply-brand-assets.py --icon … [--tv-icon …] --splash … [--tv-splash …]` writes iOS icon/splash, tvOS layered icons, top shelf, and tv launch art. **Glow** defaults off; random regenerate may enable a soft bloom with probability under 0.5; manual Glow toggle uses full strength (`glowStrength`).

## Architecture snapshot

| Target        | Platform | Shared sources                    | Notes |
|---------------|----------|-----------------------------------|-------|
| Mandaza       | iOS/tvOS | `Mandaza/`, `MandazaTV/TVContentView.swift`, `MandazaCore/` | Widget + Watch embed on iOS; TV surface on tvOS |
| MandazaWidgets| iOS      | `MandazaWidgets/`, `MandazaCore/`| Home + StandBy only (no Lock Screen accessory families) |
| MandazaWatch  | watchOS  | `MandazaWatch/`, `MandazaCore/`  | Companion face |
| MandazaTests  | iOS      | `MandazaTests/`, `MandazaCore/`   | Unit tests |

## Outstanding (suggested)

- Upload ASC metadata + `screenshots/en-US/` hero set (1320×2868) and Watch faces (422×514); keep [APP_STORE_PACK.md](APP_STORE_PACK.md) current.
- TestFlight / privacy questionnaire / beta review items in [TESTFLIGHT.md](TESTFLIGHT.md).
- iOS settings: Zen controls prominent; website link at bottom of Settings.
- Zen presentation: opacity, container, font style/weight, form, position,
  size; music responsivity + continuous tilt controls (amount / depth / axes /
  invert), faint ambient parallax sway at rest, and Void/Paper canvas themes.
- tvOS controls are intentionally two-tier: slim quick rail for frequent actions and Ambient Options for deeper tuning.
- iOS icon + launch splash and tvOS brand assets derive from `scripts/apply-brand-assets.py`; rerun when refreshing store art.
- **Device signing:** follow [PROVISIONING.md](PROVISIONING.md) to register Apple TV and ensure the shared App ID (`com.lukesteuber.mandaza`) supports tvOS + App Groups for on-device runs.
- Optional: Apple TV **Top Shelf** extension (still images + deep link) for home-screen presence.
- Refine **tvOS Brand Assets** in Xcode if actool warns about App Icon / Top Shelf collections (cosmetic; build can succeed with a primary tv icon).
- Parallax follow-up: map CoreMotion gravity through the active interface
  orientation before promising landscape direction parity; add injectable
  motion samples for lifecycle/orientation tests.
- Profile whether always-on non-Zen motion should remain at 60 Hz or use a
  lower cadence; Zen ambient sway and Watch already stop under Reduce Motion,
  backgrounding, and Always-On dimming.

## Verification

- `xcodebuild -scheme Mandaza -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' test`
- `xcodebuild -scheme Mandaza -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build`
- **Release scripts:** `scripts/archive.sh` and `scripts/archive-tvos.sh` run the same gates by default (`SKIP_TESTS=1` skips them).
- **tvOS store pipeline:** `scripts/archive-tvos.sh` → `scripts/export-ipa-tvos.sh` → `scripts/upload-testflight.sh --tvos` (same App Store Connect app record as iOS; see [TESTFLIGHT.md](TESTFLIGHT.md))
