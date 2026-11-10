# MandazaTV for Samsung TV

This directory contains the offline Samsung Tizen TV edition of MandazaTV.

## What it includes

- Full-screen procedural Mandaza canvas with local clock.
- Remote-first dock with visible focus for New Pattern, Next Palette, and Clock.
- Arrow navigation, Select activation, Play/Pause regeneration, and two-stage Back behavior: close the dock, then exit.
- Local persistence for palette and clock visibility.
- Incremental 1920×1080 canvas reveal tuned for the 2020 TU8000 runtime, with
  glow disabled for smooth physical-device motion.
- No account, tracking, network dependency, or touch-only primary flow.

The renderer is adapted from the MIT-licensed Mandaza web artwork. Samsung-specific packaging and release state are documented in `INTAKE.md` and `RELEASE.md`.

## Build and install

`package.sh` needs Tizen Studio with the Samsung TV extensions (`TIZEN_ROOT`,
default `$HOME/tizen-studio`) and a checkout of the `platforms` packaging tool
with its virtual environment (`PLATFORMS_ROOT`). That tool is not part of this
repository; without it, package `samsung/tizen` with `tizen package -t wgt`.
`install.sh` takes the TV's address on your network; the TV must be in
Developer Mode with your computer's address allowed.

```sh
export TIZEN_ROOT="$HOME/tizen-studio"
export PLATFORMS_ROOT=/path/to/platforms
samsung/scripts/package.sh
samsung/scripts/install.sh <tv-ip>
```

Launch after installation:

```sh
"$TIZEN_ROOT/tools/ide/bin/tizen" run \
  -p MandazaTV1.MandazaTV \
  -s <tv-ip>:26101
```

## Device status

The development widget is installed and running on a physical
UN50TU8000FXZA. The 2026-08-09 physical pass confirmed clock paint, full-canvas
geometry, incremental reveal, and smooth glow-free animation. Sleep/wake and
long-run checks remain release gates; see [RELEASE.md](RELEASE.md).
