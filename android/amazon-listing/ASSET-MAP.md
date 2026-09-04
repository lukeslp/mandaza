# Amazon Appstore asset map — Mandaza tablet

Target binary: `app.mandaza.android` 1.3.3 (10306), Fire tablets only.

## Copy sources

- Title: `Mandaza`
- Short description source: `play/listing/en-US/short-description.txt`
- Long description source: `play/listing/en-US/full-description.txt`
- Support and privacy URLs: verify the current values in `APP_STORE_PACK.md`
  before entering them in the console.
- Reviewer note: no account is required; microphone access is optional, used
  only for local music responsiveness, and audio is never stored or sent.

## Visual sources

| Amazon field | Source | State |
|---|---|---|
| App icon | `Mandaza/Assets.xcassets/AppIcon.appiconset/icon-1024.png` | Source identified; export to Amazon's current dimensions |
| Fire-tablet screenshots | Capture from the exact signed 10306 APK | Open; do not use phone, tvOS, Fire TV, or Samsung captures |
| Promotional image | Derive from a current 10306 renderer frame if required | Open |

The screenshot sequence should show the main mandala canvas, Zen clock,
Tune/settings, palette controls, and Void/Paper modes. Include microphone UI
only if it is exercised successfully on the same physical Fire tablet.

## Integrity rule

The APK hash, certificate, device details, and screenshot capture date must
match `android/AMAZON-TABLET-EVIDENCE.md`. Any binary change invalidates the
screenshots and the device evidence.
