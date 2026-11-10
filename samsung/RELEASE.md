# MandazaTV Samsung release track

The Samsung track is independent from Fire TV and Apple TV. Advance it only when the matching evidence exists.

- [x] Scaffold: offline widget, `config.xml`, icon, remote controls.
- [x] Build: signed `.wgt` exists under the ignored `tizen/dist/platforms/tizen/` output root.
- [x] Validate: widget contents, version, icon, checksum, archive integrity, and signing state inspected.
- [x] Device install: UN50TU8000FXZA — latest development
  widget installed and launched 2026-08-09 (`c24fec9` Samsung content).
- [x] Visual QA: clock paints real local time; full-screen weave renders;
  incremental glow-free reveal is visibly smooth on the physical panel.
- [ ] Remaining device QA: full remote matrix, offline relaunch, sleep/wake,
  and long-run behavior.
- [ ] Store stage: Samsung certificate profile and Seller Office assets/checklist are ready.
- [ ] Submit: human-authorized Seller Office upload only.

## Local commands

```sh
samsung/scripts/package.sh
samsung/scripts/install.sh <tv-ip>
```

The package currently uses Tizen's default development certificate. The physical TV accepts it for local sideloading; Seller Office submission requires a Samsung author/distributor profile and a newly signed package.

Local 1920×1080 browser verification also confirmed a rendered canvas, no external network requests, visible focus movement, palette activation, status announcements, and the two-stage Back/Exit path without script errors.

Physical tuning history: unsupported Tizen syntax was removed, the renderer
was changed from full-frame path replay to incremental segment painting, live
glow was disabled, reveal colors were cached, and clock DOM updates were moved
off the animation loop. A 1600×900 experiment reduced clarity without changing
cadence and was reverted; the installed widget uses a 1920×1080 backing canvas.
