# Mandaza — project plan

## Current objectives

- **iOS / iPadOS:** Ship on-device generative mandalas, WidgetKit surfaces, Photos export, `mandaza://` deep links.
- **tvOS:** Ship a fullscreen ambient companion app (screensaver-like while the app is open) with in-app “widget-style” control panels; no system screensaver or WidgetKit (not available to third parties on tvOS).
- **Shared:** Single `MandazaCore` engine and App Group–backed settings; `project.yml` + XcodeGen as the project source of truth.

## Architecture snapshot

| Target        | Platform | Shared sources                    | Notes |
|---------------|----------|-----------------------------------|-------|
| Mandaza       | iOS      | `Mandaza/`, `MandazaCore/`        | Widget extension dependency |
| MandazaWidgets| iOS      | `MandazaWidgets/`, `MandazaCore/`| WidgetKit only |
| MandazaTV     | tvOS     | `MandazaTV/`, `MandazaCore/`, `Mandaza/MandazaCanvas.swift` | No Photos / WidgetKit |
| MandazaTests  | iOS      | `MandazaTests/`, `MandazaCore/`   | Unit tests |

## Outstanding (suggested)

- App Store / marketing assets and license file (README still “TBD”).
- **Device signing:** follow [PROVISIONING.md](PROVISIONING.md) to register Apple TV + App ID (`com.lukesteuber.mandaza.tv`) with App Groups for on-device tvOS runs.
- Optional: Apple TV **Top Shelf** extension (still images + deep link) for home-screen presence.
- Refine **tvOS Brand Assets** in Xcode if actool warns about App Icon / Top Shelf collections (cosmetic; build can succeed with a primary tv icon).

## Verification

- `xcodebuild -scheme Mandaza -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- `xcodebuild -scheme MandazaTV -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build`
