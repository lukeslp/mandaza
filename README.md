# Mandala

A native iOS app that draws animated hexagonal-loop mandalas in real time
and exports them as wallpaper-resolution images.

Originally a single HTML page; this is a faithful port to SwiftUI Canvas
with a tap-to-regenerate UI, a palette picker, and Save-to-Photos export.

## Build

```sh
brew install xcodegen          # if not installed
xcodegen
open Mandala.xcodeproj
```

Or from the command line:

```sh
xcodegen
xcodebuild -scheme Mandala -destination 'generic/platform=iOS Simulator' build
```

## Project layout

```
Mandala/
  MandalaApp.swift        App entry
  ContentView.swift       Top-level UI: canvas + control bar + palette sheet
  MandalaCanvas.swift     SwiftUI Canvas + TimelineView animation host
  MandalaEngine.swift     Algorithm port: cells, dots, loops, beziers
  Palettes.swift          Color palettes + interpolation
  ExportService.swift     PHPhotoLibrary save + wallpaper presets
  Assets.xcassets/        AppIcon, AccentColor
MandalaTests/             Engine smoke tests
project.yml               xcodegen spec
```

## Interactions

- Single tap shows / hides the floating control bar.
- Double tap regenerates the pattern with a fresh palette.
- Save button writes the current screen at native pixel size to Photos.
- The export menu offers preset wallpaper resolutions.
