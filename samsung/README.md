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

The renderer is adapted from Luke Steuber's MIT-licensed Mandaza web artwork. Samsung-specific packaging and release state are documented in `INTAKE.md` and `RELEASE.md`.

## Build and install

```sh
samsung/scripts/package.sh
samsung/scripts/install.sh 192.168.0.123
```

Launch after installation:

```sh
/Volumes/Galactus/tizen-studio/tools/ide/bin/tizen run \
  -p MandazaTV1.MandazaTV \
  -s 192.168.0.123:26101
```

## Device status

The development widget is installed and running on the UN50TU8000FXZA at
`192.168.0.123`. The 2026-08-09 physical pass confirmed clock paint, full-canvas
geometry, incremental reveal, and smooth glow-free animation. Sleep/wake and
long-run checks remain release gates; see [RELEASE.md](RELEASE.md).
