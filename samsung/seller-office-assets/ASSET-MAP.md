# MandazaTV Samsung Seller Office assets

Upload the files in this directory to Samsung Apps TV Seller Office →
**Applications → App Images**. The files are final upload assets, not working
sources.

| Seller Office field | File | Delivered format | Limit | Status |
|---|---|---|---|---|
| 1920×1080 logo asset with transparency | `logo-asset-transparent-1920x1080.png` | 1920×1080, 32-bit RGBA PNG | <300 kB | Ready |
| 1920×1080 background image | `background-1920x1080.jpg` | 1920×1080, 24-bit RGB JPG | <300 kB | Ready |
| 512×423 full-color asset | `full-color-asset-512x423.png` | 512×423, 24-bit RGB PNG | <300 kB | Ready |
| Screenshot 1 | `screenshots/01_aurora-controls-1920x1080.jpg` | 1920×1080 JPG | <500 kB | Ready |
| Screenshot 2 | `screenshots/02_ember-controls-1920x1080.jpg` | 1920×1080 JPG | <500 kB | Ready |
| Screenshot 3 | `screenshots/03_vaporwave-ambient-1920x1080.jpg` | 1920×1080 JPG | <500 kB | Ready |
| Screenshot 4 | `screenshots/04_riso-art-1920x1080.jpg` | 1920×1080 JPG | <500 kB | Ready |
| App description | `MandazaTV_App_Description_v1.3.0_EN.pptx` | Samsung v1.42 English template, 9 slides | Seller Office upload | Ready |

Samsung automatically generates the 16:9 and 1:1 full-color 1920×1080 icon
assets from the transparent logo and background. Keep the provided full-color
512×423 image; it is the separate required small icon.

## Current Samsung requirements

- Target: Samsung Apps TV Seller Office; Tizen TV application
  `MandazaTV1.MandazaTV`, targeted at Samsung UN50TU8000FXZA / Tizen 5.5+
- Retrieved: 2026-08-10
- Official image-entry guide:
  https://developer.samsung.com/tv-seller-office/guides/applications/entering-application-information.html
- Official icon and screenshot specification:
  https://developer.samsung.com/smarttv/design/app-icons-and-screenshots.html
- Official launch checklist:
  https://developer.samsung.com/tv-seller-office/checklists-for-distribution/launch-checklist.html

Those sources require both icon sizes and **four** JPEG screenshots. They state
that the large transparent logo is 1920×1080, 32-bit RGBA PNG below 300 kB;
the background is 1920×1080 24-bit RGB PNG/JPG below 300 kB; the small
full-color icon is 512×423 RGB PNG below 300 kB; and each screenshot is
1920×1080 JPG below 500 kB.

## Provenance

The large background is the 2026-08-10 pure Mandaza artwork capture from the
live `mandaza.app` renderer. The logo and full-color asset use the current
MandazaTV icon, reformatted to Samsung's required safe compositions.

The four screenshots were rendered at an exact 1920×1080 browser viewport from
the Tizen package's `samsung/tizen/index.html`, with a fixed palette and a
faster capture-only reveal so the same final procedural geometry could settle
inside the capture window. The Samsung test TV was offline during
asset preparation, so these are not represented as physical-panel captures.
They show the shipped Tizen renderer and its remote-first controls; replace
them with an equivalent physical capture only if later Samsung review requests
device proof.

Captions and alt text for every upload image are in
`SCREENSHOT-METADATA.md`; hashes are in `SHA256SUMS.txt`.

`MandazaTV_App_Description_v1.3.0_EN.pptx` is the completed English app
description for Seller Office. It follows Samsung's supplied v1.42 PowerPoint
template and records the actual shipped Tizen screen, remote behavior, exit
flow, offline operation, and English-only language support. Its speaker notes
identify the local source code and renderer captures used for each claim.
