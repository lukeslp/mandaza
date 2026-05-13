# Mandaza App Store Pack

This document is the single source of truth for App Store and TestFlight submission assets, metadata, copy, and runbooks for both iOS and tvOS listings.

## Scope

- iOS app listing: `com.lukesteuber.mandaza`
- tvOS app listing: `com.lukesteuber.mandaza.tv`
- Widget extension bundle: `com.lukesteuber.mandaza.widgets` (not a separate store listing)

## IDs and Platform Records

| Item | Value |
|---|---|
| Team ID | `596T7J7FB6` |
| App Group | `group.com.lukesteuber.mandaza` |
| iOS bundle ID | `com.lukesteuber.mandaza` |
| tvOS bundle ID | `com.lukesteuber.mandaza.tv` |
| Widgets bundle ID | `com.lukesteuber.mandaza.widgets` |

Both iOS and tvOS require separate app records in App Store Connect because they use different bundle IDs.

## App Store Metadata Pack

### iOS Listing

#### Name and Discoverability

- App Name: `Mandaza`
- Subtitle: `Procedural ambient art`
- Keywords (100-char target):
  - `mandala,procedural,generative,wallpaper,ambient,zen,art,widget,standby,patterns`

#### Promotional Text (170 chars max)

`Generate luminous procedural mandalas, save wallpaper-ready images, and keep your favorites rotating in widgets and StandBy.`

#### Full Description

Mandaza creates procedural ambient mandalas on your device in real time.

Tap to generate a new pattern, tune the look, and save high-resolution images for wallpapers. Keep favorites and let your widgets rotate through them automatically.

Features:
- Real-time generative canvas with smooth animated loop drawing
- 11 curated color palettes
- Zen Mode with optional clock overlay and style controls (opacity, container, font, position)
- Favorites with quick recall
- Lock Screen, Home Screen, and StandBy widgets
- Export presets for iPhone, iPad, and Square 4K
- Deterministic seeds for reproducible visuals

Privacy first:
Mandaza runs on-device, with no account and no analytics.
The only permission requested is write access to Photos when you choose Save.

Questions or feedback: luke@lukesteuber.com

#### What to Test (TestFlight)

- Tap canvas or New button to generate patterns.
- Open Settings to adjust palette, density, geometry, and speed.
- Save an image to Photos and verify success path + permission prompts.
- Favorite/unfavorite a pattern and confirm it appears in Favorites.
- Verify widget behavior (Home, Lock, StandBy): seed rotation and deep-link opening.
- Confirm deep-link format: `mandaza://seed/<UUID>`.

### tvOS Listing

#### Name and Discoverability

- App Name: `Mandaza` (or `Mandaza TV` if naming collision)
- Subtitle: `Ambient procedural art`
- Keywords (100-char target):
  - `ambient,apple tv,mandala,procedural,generative,zen,art,screensaver,visual`

#### Promotional Text (170 chars max)

`Turn your Apple TV into a living ambient canvas with procedural mandalas, Zen clock overlays, and remote-friendly controls.`

#### Full Description

MandazaTV is a fullscreen ambient visual experience for Apple TV.

Generate endlessly varied procedural mandalas, switch palettes, and tune Zen options from a remote-friendly control dock.

Features:
- Fullscreen animated procedural mandalas
- Play/Pause to generate a new composition
- Menu to show or hide controls
- Zen clock/date overlay options with style controls (opacity, container, font, position)
- Shared visual language with the iOS app

MandazaTV runs on-device and does not require an account.

#### What to Test (TestFlight)

- Play/Pause generates a new pattern.
- Menu toggles the dock.
- Dock auto-hides after idle and can be restored with Menu.
- Zen sheet controls update overlay behavior.
- General smoothness in long-running ambient mode.

## Privacy and Compliance Pack

### Privacy Nutrition Label

- Data collection: `None`
- Tracking: `No`
- Linked to user: `No`
- Used for tracking: `No`

### Encryption

- `ITSAppUsesNonExemptEncryption = false` is set in project config.
- Export compliance answer remains "No non-exempt encryption."

### Privacy Policy URL

- Use: `https://lukeslp.github.io/mandaza/`
- Confirm URL is public and renders before each submission cycle.

## Assets Pack

### App Icons

- iOS app icon source in asset catalog:
  - `Mandaza/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- tvOS brand assets and top shelf images in:
  - `MandazaTV/Assets.xcassets/AppIcon.brandassets/`

### Launch/Splash

- iOS launch configured via `UILaunchScreen` with `AccentColor`.
- tvOS launch uses standard launch screen configuration (`UILaunchScreen: {}`).

### Screenshot Checklist

Prepare and upload these per-store listing:

- iOS listing:
  - iPhone screenshots (required set for your supported iPhone classes)
  - iPad screenshots (recommended/required based on iPad support)
  - Optional app preview video
- tvOS listing:
  - Apple TV screenshots
  - Optional tvOS app preview video

Use short, legible overlays with one core message per frame.

## App Review Notes Pack

### iOS Review Notes (paste-ready)

- Mandaza is an on-device procedural art app with no sign-in and no analytics.
- Main flow: tap New or canvas to regenerate ambient mandala patterns.
- Save uses Photos add permission only.
- Widgets support Home Screen, Lock Screen, and StandBy with configurable palette/rotation.
- Deep link format: `mandaza://seed/<UUID>`.
- If assistive technologies are enabled, long-press behavior may differ; New button is canonical.

### tvOS Review Notes (paste-ready)

- MandazaTV is an ambient fullscreen procedural art experience.
- Play/Pause generates a new pattern.
- Menu shows/hides the control dock.
- Dock also auto-hides after idle and is restored via Menu.
- No account, no network backend required for core behavior.

## Submission Runbook

### Preconditions

- App IDs exist and are capability-aligned.
- App Group `group.com.lukesteuber.mandaza` is enabled for iOS, widgets, and tvOS IDs.
- App records exist in App Store Connect for both iOS and tvOS bundle IDs.
- API key is present in `~/.appstoreconnect/private_keys/`.
- `ASC_API_ISSUER` is exported in shell.

### iOS Build and Upload

`archive.sh` runs **unit tests** on the iPhone 17 simulator, then archives. Use `SKIP_TESTS=1` only for a quick local archive when you intentionally accept untested bits.

```bash
scripts/archive.sh
scripts/export-ipa.sh
scripts/upload-testflight.sh
```

### tvOS Build and Upload

`archive-tvos.sh` runs a **Debug tvOS Simulator build** smoke, then the Release archive. Same `SKIP_TESTS=1` escape hatch.

```bash
scripts/archive-tvos.sh
scripts/export-ipa-tvos.sh
scripts/upload-testflight.sh --tvos
```

### Post-upload Checklist

- Build appears in TestFlight processing queue.
- Export compliance confirmation is complete.
- "What to Test" fields are filled.
- Internal testing starts.
- For public testing: submit for Beta App Review, then enable Public Link.

## Release Checklist (Single Pass)

- [ ] Metadata pasted (name, subtitle, promo text, description, keywords)
- [ ] Privacy label completed (None)
- [ ] Privacy policy URL verified live
- [ ] Icons verified in ASC preview
- [ ] Screenshots uploaded for active platform listing
- [ ] Review notes pasted
- [ ] IPA uploaded and processed
- [ ] Beta review submitted (if public external testing)
- [ ] Public link enabled (if needed)

## Ownership and Update Rule

Whenever release copy, assets, or submission flow changes, update this file first, then mirror any concise summary updates into `README.md` and `PROJECT_PLAN.md`.
