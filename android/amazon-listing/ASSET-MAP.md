# Amazon Appstore asset map — Mandaza tablet

Target binary: `app.mandaza.android` 1.3.3 (10308), Fire tablets only.

## Copy sources

- Title: `Mandaza`
- Short description source: `play/listing/en-US/short-description.txt`
- Long description source: `play/listing/en-US/full-description.txt`
- Support and privacy URLs: `https://mandaza.app/` and
  `https://mandaza.app/privacy.html`; verify both before entering them in the
  console.
- Reviewer note: no account is required; microphone access is optional, used
  only for local music responsiveness, and audio is never stored or sent.

## Visual sources

| Amazon field | Source | State |
|---|---|---|
| App icon | `Mandaza/Assets.xcassets/AppIcon.appiconset/icon-1024.png` | Source identified; export to Amazon's current dimensions |
| Fire-tablet screenshots | `screenshots/01-main.png` through `05-new-pattern.png` | Captured from exact 10308 APK on Amazon KFRASWI, 2026-09-04 |
| Promotional image | Derive from a current 10308 renderer frame if required | Open |

The screenshot sequence shows the main mandala canvas, Zen clock,
Tune/palette controls, Paper mode, and a newly generated pattern. Microphone
permission UI is deliberately excluded from customer-facing assets.

| File | SHA-256 |
|---|---|
| `screenshots/01-main.png` | `a13786b1ccf459f0807473b574af0908a30a1bfa653d98e4fcaa124df6902308` |
| `screenshots/02-zen.png` | `7ae778f51fc97b2aa6fceb5d1c6376c8cf06053a0a8b9acf1167e870b95485a3` |
| `screenshots/03-tune.png` | `24302024ab3e98476695e5f0096e3e38a3ab1371d2dda728ff4b7b9fe8ffbfa5` |
| `screenshots/04-paper.png` | `f5e3973f3847ed9ae2e67917dd9501af34e1de9d1bbc16e67d3a93767052dfa3` |
| `screenshots/05-new-pattern.png` | `de8c684c9381dbe445a15212e34c7a47021512e3cd1cf14c1b97b896d7c66752` |

## Integrity rule

The APK hash, certificate, device details, and screenshot capture date must
match `android/AMAZON-TABLET-EVIDENCE.md`. Any binary change invalidates the
screenshots and the device evidence.
