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

`Generate luminous procedural mandalas, let Music Mode pulse them to the sound in the room, and send any design straight to your Apple Watch face.`

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
- Music Mode: press and hold the New button and the mandala listens — stroke width, glow, and color pulse live with the ambient sound in the room
- Apple Watch companion: a full watch face with tap to regenerate, Digital Crown to cycle palettes, and long-press for settings — your iPhone's look mirrors to the watch automatically, and Send to Watch pushes the current or any favorited design to your wrist instantly

Privacy first:
Mandaza runs on-device, with no account and no analytics.
Photos access is requested only when you choose Save. Microphone access is requested only if you turn on Music Mode, to read ambient sound levels for the live visual pulse — audio is processed in memory and is never recorded, stored, or sent anywhere.

Questions or feedback: luke@lukesteuber.com

#### Keywords (100-char target)

`mandala,procedural,generative,wallpaper,ambient,zen,art,widget,standby,patterns,music,watch,reactive`

(All 10 existing terms kept; added `music`, `watch`, `reactive` for the 1.3 features. Dropped candidates `visualizer` and `applewatch` as redundant once `music`/`reactive`/`watch` are present — no budget for both.)

#### What to Test (TestFlight)

- Tap canvas or New button to generate patterns.
- Open Settings to adjust palette, density, geometry, and speed.
- Save an image to Photos and verify success path + permission prompts.
- Favorite/unfavorite a pattern and confirm it appears in Favorites.
- Verify widget behavior (Home, Lock, StandBy): seed rotation and deep-link opening.
- Confirm deep-link format: `mandaza://seed/<UUID>`.
- Long-press the New button to enable Music Mode; confirm the priming explanation appears before the system mic prompt.
- Deny microphone access and confirm Music Mode fails gracefully (no crash, clear guidance in Settings > Music Mode).
- Grant microphone access and confirm the New button's live ring pulses with real ambient sound.
- Background the app while Music Mode is active; confirm the mic stops and resumes correctly on return.
- Open Settings > Apple Watch and confirm pairing status reflects reality (paired/unpaired, watch app installed/not).
- Trigger "Send to Watch" (Save menu, and from a Favorite) with the Watch app open and confirm the design appears immediately; with it closed, confirm it's waiting on next open.
- Change palette, density, glow, or line width on iPhone and confirm the watch face auto-syncs without manual action.
- With VoiceOver or Switch Control on, confirm Music Mode is reachable via Settings even though the New button's long-press is disabled.

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

Generate endlessly varied procedural mandalas, switch palettes, and tune Zen options from an ambient-first quick control rail with a secondary deep settings sheet.

Features:
- Fullscreen animated procedural mandalas
- Play/Pause to generate a new composition
- Menu to hide controls in ambient mode and restore them when hidden
- Directional swipe restores controls when hidden
- Zen clock/date overlay options with style controls (opacity, container, font, position)
- Shared visual language with the iOS app

MandazaTV runs on-device and does not require an account.

#### What to Test (TestFlight)

- Play/Pause generates a new pattern.
- **Touch surface click** (Select) on the canvas while the dock is hidden generates a new pattern (invisible focus target; same as iPhone tap-to-new).
- Menu hides/restores the dock; with the dock hidden, Menu must **not** drop to the TV home screen (regression: missing focus).
- Dock auto-hides after idle; after hide, **directional swipe** or Menu brings the dock back.
- Quick rail (New / Zen / Ambient Options / Palettes) behaves without opening deep settings unless intended.
- Ambient Options sheet: Menu dismisses the sheet; dock focus returns sensibly.
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

### Apple TV (tvOS) — Privacy Policy in App Store Connect

Apple asks for a **Privacy Policy URL** on the **tvOS** app record the same way
as on iOS. You do **not** need a different domain for Apple TV if one policy
covers both apps.

1. In [App Store Connect](https://appstoreconnect.apple.com), open the app
   whose bundle ID is **`com.lukesteuber.mandaza.tv`** (the tvOS listing, not
   the iPhone app).
2. Go to **App Privacy** (left sidebar, under **General** or the app's trust
   section depending on ASC layout).
3. Set **Privacy Policy** to the **same public URL** as iOS:
   `https://lukeslp.github.io/mandaza/`
4. Complete **App Privacy** answers for the tvOS app (**Data collection: None**,
   **Tracking: No**) so they match the iOS app and match your
   `PrivacyInfo.xcprivacy` / nutrition label story.

The hosted policy in [`docs/index.md`](docs/index.md) explicitly includes an
**Apple TV (tvOS)** section so reviewers see tvOS covered at that URL.

If ASC ever shows a separate “Apple TV Privacy Policy” text field (rare), paste
the same URL there, or paste the tvOS subsection headings plus body from
`docs/index.md` as plain text—prefer keeping a **single canonical URL** so you
only maintain one document.

## Assets Pack

### App Icons

- iOS app icon source in asset catalog:
  - `Mandaza/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- tvOS brand assets and top shelf images in:
  - `MandazaTV/Assets.xcassets/AppIcon.brandassets/`

### Launch/Splash

- iOS launch configured via `UILaunchScreen` with `AccentColor` + `LaunchSplash` image.
- tvOS launch uses `UILaunchScreen` with `AccentColor` + `LaunchSplash` (see `project.yml`; regenerated Info.plist mirrors iOS pattern).

### Screenshot Checklist

Prepare and upload these per-store listing:

- iOS listing:
  - iPhone screenshots (required set for your supported iPhone classes)
  - iPad screenshots (recommended/required based on iPad support)
  - Apple Watch Ultra screenshot set (rides the iOS listing, `APP_WATCH_ULTRA` display type — not a separate record)
  - Optional app preview video
- tvOS listing:
  - Apple TV screenshots (unchanged in 1.3 — reuse existing set)
  - Optional tvOS app preview video

Use short, legible overlays with one core message per frame. Staging directory: `screenshots/en-US/` (see `NOTES.md` there for capture provenance and outstanding recaptures).

#### Apple Watch screenshot set (new in 1.3, 5-6 frames)

1. **Hero** — the watch face itself, full mandala fill. Caption: "A generative mandala face for Apple Watch."
2. **Tap to regenerate** — face mid-transition between two seeds. Caption: "Tap the face for a new pattern."
3. **Digital Crown palette cycling** — Crown highlighted, two palette swatches shown. Caption: "Turn the Crown to cycle palettes."
4. **Long-press settings** — the settings sheet open (Music Mode toggle, sync status). Caption: "Long-press for quick settings."
5. **Send to Watch** — iPhone with a favorited design and "Send to Watch," watch face updating to match. Caption: "Send any design straight to your wrist."
6. **Automatic mirroring (CTA)** — iPhone Settings (palette/density/glow/line width) next to the matching watch face. Caption: "Your look, mirrored automatically."

#### iPhone screenshot additions (2 new frames, slot after the core canvas/widget shots)

- **Music Mode active** — canvas with the New button's live pulse ring visible mid-glow. Caption: "Music Mode listens and the mandala pulses."
- **Apple Watch settings** — Settings > Apple Watch screen (pairing status, auto-mirror toggle, Send to Watch). Caption: "One look, everywhere you wear it."

## App Review Notes Pack

### iOS Review Notes (paste-ready)

- Mandaza is an on-device procedural art app with no sign-in and no analytics.
- Main flow: tap New or canvas to regenerate ambient mandala patterns.
- Save uses Photos add permission only.
- Widgets support Home Screen, Lock Screen, and StandBy with configurable palette/rotation.
- Deep link format: `mandaza://seed/<UUID>`.
- If assistive technologies are enabled, long-press behavior may differ; New button is canonical.
- Long-press the New button to toggle **Music Mode**: microphone access is used only for local, on-device audio-reactive visuals (stroke width, glow, and color pulse react to ambient sound levels in real time). Audio is never recorded, saved, or uploaded, and there is no integration with any streaming or third-party audio service. The permission is requested only when the user turns it on, with a priming explanation shown first. With VoiceOver/Switch Control active, the long-press is disabled and Music Mode is reachable instead via Settings > Music Mode (an ordinary Toggle).
- Mandaza includes an Apple Watch companion app that syncs over WatchConnectivity. The iPhone app mirrors its current look (palette, density, glow, line width) to the paired watch automatically, and includes a "Send to Watch" action (Save menu, and on any Favorite) that pushes a design to the watch immediately. This paired-device sync is expected behavior between the two apps under the same Team ID / App Group and is not unexpected background networking.

### tvOS Review Notes (paste-ready)

- MandazaTV is an ambient fullscreen procedural art experience.
- **Siri Remote:** Play/Pause always generates a new pattern. **Menu** toggles the control dock (hidden ↔ visible). When the dock is hidden, a **full-screen focusable surface** captures Select / Menu / Play Pause / directional swipes so the system does not send Menu to the TV home screen.
- **Touch surface:** Click (Select) while ambient = new pattern; swipe when ambient = show dock (same as Menu when hidden).
- Dock auto-hides after idle; restore with Menu or swipe.
- No account, no network backend required for core behavior.

## What's New in 1.3 (Release Notes)

Mandaza 1.3 adds Music Mode: press and hold the New button and the mandala's stroke width, glow, and color pulse live with the ambient sound in the room. Nothing is recorded — it's a live visual reaction, entirely on-device. This update also brings a fuller Apple Watch companion: tap to regenerate, turn the Digital Crown to cycle palettes, and use Send to Watch from your iPhone to push any design straight to your wrist. Your iPhone's look now mirrors to the watch automatically.

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
- [ ] Privacy policy URL verified live (iOS **and** tvOS app records in ASC)
- [ ] Icons verified in ASC preview
- [ ] Screenshots uploaded for active platform listing
- [ ] Review notes pasted
- [ ] IPA uploaded and processed
- [ ] Beta review submitted (if public external testing)
- [ ] Public link enabled (if needed)

## Ownership and Update Rule

Whenever release copy, assets, or submission flow changes, update this file first, then mirror any concise summary updates into `README.md` and `PROJECT_PLAN.md`.
