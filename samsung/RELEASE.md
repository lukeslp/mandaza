# MandazaTV Samsung release track

The Samsung track is independent from Fire TV and Apple TV. Advance it only when the matching evidence exists.

- [x] Scaffold: offline widget, `config.xml`, icon, remote controls.
- [x] Build: signed `.wgt` exists under the ignored `tizen/dist/platforms/tizen/` output root.
- [x] Validate: widget contents, version, icon, checksum, archive integrity, and signing state inspected.
- [x] Device install: UN50TU8000FXZA (`192.168.0.123`) — re-packaged + installed + launched 2026-08-08 evening with clock/remote fixes (`ea8222b` content).
- [ ] Device QA: physical remote (Select/Play new pattern, arrows dock, Back hide), clock not stuck on `--:--`, offline relaunch, sleep/wake, long-run.
- [ ] Store stage: Samsung certificate profile and Seller Office assets/checklist are ready.
- [ ] Submit: human-authorized Seller Office upload only.

## Local commands

```sh
samsung/scripts/package.sh
samsung/scripts/install.sh 192.168.0.123
```

The package currently uses Tizen's default development certificate. The physical TV accepts it for local sideloading; Seller Office submission requires a Samsung author/distributor profile and a newly signed package.

Local 1920×1080 browser verification also confirmed a rendered canvas, no external network requests, visible focus movement, palette activation, status announcements, and the two-stage Back/Exit path without script errors.
