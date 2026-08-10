# Amazon listing asset map — MandazaTV

Upload from this folder (`android/tv/amazon-listing/`).

| Amazon field | File | Size |
|---|---|---|
| App icon (square) | `icon-512.png` | 512×512 |
| Small icon | `icon-114.png` | 114×114 |
| Fire TV app icon | `fire-tv-app-icon-1280x720.png` | 1280×720 opaque |
| Background image | `fire-tv-background-1920x1080.jpg` | 1920×1080 |
| Screenshot 1 | `screenshots/01_main-rail-1920x1080.jpg` | 1920×1080 |
| Screenshot 2 | `screenshots/02_zen-clock-1920x1080.jpg` | 1920×1080 |
| Screenshot 3 | `screenshots/03_tune-panel-1920x1080.jpg` | 1920×1080 |
| Screenshot 4 | `screenshots/04_paper-canvas-1920x1080.jpg` | 1920×1080 |
| Screenshot 5 | `screenshots/05_ambient-canvas-1920x1080.jpg` | 1920×1080 |
| Listing copy | `amazon.txt` | — |

The background is a direct 1920×1080 capture from the live `mandaza.app`
renderer: pure Mandaza artwork with no clock, controls, logo, browser chrome, or
marketing overlay. The five screenshots are distinct physical AFTTI43 Fire TV
captures of the signed `1.3.1 (20301)` release. Captions and accessible
descriptions for every marketing image are in `SCREENSHOT-METADATA.md`.

## Verified Fire TV screenshot requirements

- Primary source: https://developer.amazon.com/docs/app-submission/appstore-details.html#fire-tv-assets
- Capture guidance: https://developer.amazon.com/docs/app-submission/taking-screenshots.html
- Test criteria: https://developer.amazon.com/docs/app-testing/test-criteria.html
- Retrieved: 2026-08-10
- Source revision shown by Amazon: 2026-01-06
- Target: Amazon Fire TV, AFTTI43 / Fire OS 7; Amazon Appstore submission
- Requirement: 3–10 screenshots, 1920×1080 landscape, JPG or opaque 24-bit PNG

The captures satisfy the documented resolution, orientation, count, and opaque
JPG format requirements. Re-check the source immediately before upload because
store-console requirements can change.

In-app Leanback banner: `tv/src/main/res/drawable*/tv_banner.png` (from Top Shelf).
