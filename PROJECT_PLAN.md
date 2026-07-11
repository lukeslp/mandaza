# Mandaza — project plan

## Current objectives

- **iOS / iPadOS:** Ship on-device generative mandalas, WidgetKit surfaces, Photos export, `mandaza://` deep links.
- **tvOS:** Ship a fullscreen ambient companion app with a quick-control rail, compact “controls hidden” hint, larger Zen clock typography, and a tvOS-safe collapsible Zen section (no `DisclosureGroup`); `UILaunchScreen` uses `LaunchSplashTV` (iOS uses `LaunchSplashIOS`) to hard-bust stale launch-screen caches.
- **Shared:** Single `MandazaCore` engine and App Group–backed settings; `project.yml` + XcodeGen as the project source of truth. Brand refreshes: `scripts/apply-brand-assets.py --icon … [--tv-icon …] --splash … [--tv-splash …]` writes iOS icon/splash, tvOS layered icons, top shelf, and tv launch art. **Glow** defaults off; random New may enable a soft bloom with probability under 0.5; manual Glow toggle uses full strength (`glowStrength`).
- **Release:** Version 1.3 across iOS, tvOS, watchOS, and widgets. Archive
  numbering increments from a tracked counter above uploaded build 55.

## Architecture snapshot

| Target        | Platform | Shared sources                    | Notes |
|---------------|----------|-----------------------------------|-------|
| Mandaza       | iOS      | `Mandaza/`, `MandazaCore/`        | Widget extension dependency |
| MandazaWidgets| iOS      | `MandazaWidgets/`, `MandazaCore/`| WidgetKit only |
| MandazaTV     | tvOS     | `MandazaTV/`, `MandazaCore/`, `Mandaza/MandazaCanvas.swift` | No Photos / WidgetKit |
| MandazaWatch  | watchOS  | `MandazaWatch/`, `MandazaCore/` | Crown palette selection + live canvas |
| MandazaTests  | iOS      | `MandazaTests/`, `MandazaCore/`   | Unit tests |

## Outstanding (suggested)

- App Store / marketing assets for the 1.3 update.
- Publish and verify the privacy policy URL; the documented GitHub Pages URL
  currently returns 404.
- Keep [APP_STORE_PACK.md](APP_STORE_PACK.md) current as the source of truth for copy, screenshots, and iOS/tvOS submission runbooks.
- iOS settings simplification: About screen removed for now; use website link at bottom of Settings and keep Zen controls prominent.
- Zen presentation controls now include opacity, container transparency, font style/weight, and position presets across tvOS and iOS (`ZenClockTypography` keeps label vs. glyph weight aligned).
- tvOS controls are now intentionally two-tier: slim quick rail for frequent actions and Ambient Options for deeper tuning.
- iOS icon + launch splash and tvOS brand assets derive from `scripts/apply-brand-assets.py` (curated iOS icon, optional `--tv-icon` for wide tv icon stacks, portrait iOS splash, optional `--tv-splash` for wide tv top shelf + tv launch); rerun when refreshing store art.
- **Device signing:** follow [PROVISIONING.md](PROVISIONING.md) to register Apple TV + App ID (`com.lukesteuber.mandaza.tv`) with App Groups for on-device tvOS runs.
- **Privacy:** `MandazaCore/PrivacyInfo.xcprivacy` declares no tracking or
  collection and covers app-only plus App Group `UserDefaults` access.
- Optional: Apple TV **Top Shelf** extension (still images + deep link) for home-screen presence.
- Refine **tvOS Brand Assets** in Xcode if actool warns about App Icon / Top Shelf collections (cosmetic; build can succeed with a primary tv icon).
- Complete VoiceOver, Switch Control, Siri Remote, and Digital Crown testing on
  physical devices before submitting 1.3.
- Migrate fixed-size control typography to semantic Dynamic Type styles and
  verify all accessibility content sizes.

## Verification

- `xcodebuild -scheme Mandaza -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- `xcodebuild -scheme MandazaTV -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build`
- Current automated result: 25 tests pass; iOS app/widgets/watch and tvOS build
  successfully under Xcode 26.5.
- **Release scripts:** `scripts/archive.sh` and `scripts/archive-tvos.sh` run the same gates by default (`SKIP_TESTS=1` skips them).
- **tvOS store pipeline:** `scripts/archive-tvos.sh` → `scripts/export-ipa-tvos.sh` → `scripts/upload-testflight.sh --tvos` (requires App Store Connect app for `com.lukesteuber.mandaza.tv`; see [TESTFLIGHT.md](TESTFLIGHT.md))
