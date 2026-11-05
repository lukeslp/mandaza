# Attribution and dependency review

Mandaza's first-party code is MIT licensed; see `LICENSE`. Luke Steuber's
author credit is retained. This inventory does not relicense third-party work.

## Seeded random generator

The native generator translates Dillon's seed/repeated-`A` Mash wrapper,
following the variant published by Gibson Research Corporation / Steve Gibson,
based on Johannes Baagøe's Mash hash. Preserve Baagøe's 2010 MIT terms in
`LICENSES/Johannes-Baagoe-MIT.txt`, Dillon's MIT notices below, and the exact
GRC public-domain release in `LICENSES/GRC-Public-Domain.txt`.
The full GRC 48-word UHEPRNG/MWC engine and entropy APIs are not included.
Native Unicode handling is an adaptation, not identical output for every
JavaScript seed. Primary GRC source: https://www.grc.com/js/uheprng.js

Primary reference and original notice:
https://github.com/davidbau/seedrandom/blob/released/lib/alea.js

## Hexagonal loop construction

The native engine adapts Dillon (Dillo)'s MIT-licensed source family:
Controlled loops on hexagons, https://codepen.io/Dillo/pen/NWPWoYO, based on
Loops on hexagons, https://codepen.io/Dillo/pen/xvXjLZ.
Their Details pages explicitly display full MIT grants, preserved in
`LICENSES/Dillon-Controlled-Loops-MIT.txt` and `LICENSES/Dillon-Loops-MIT.txt`.
The displayed notice year is 2026; the works' creation dates are 2019.
The notices retain the actual displayed year rather than inventing one.

Distinctive tables, fractions, partner selection and partition operations
establish the source family. The intermediate Mandaza HTML changes topology
and Bézier details; its exact historical revision is not recorded. This is an
adaptation, not an unchanged upstream export. See `docs/FDROID_PROVENANCE.md`.
Earlier Charlotte Dann / David Siaw credits identify related artistic references,
not the demonstrated source of this engine. Truchet's historical mathematics
does not put modern implementations in the public domain.

## Android runtime dependencies

The exact 96 runtime coordinates, 63 binary artifacts, source locations and
official hashes are recorded in `docs/FDROID_COMPONENTS.json`. The principal
license is Apache-2.0 (`LICENSES/Apache-2.0.txt`). Additional supplied/embedded
notices are retained with the source and under `assets/licenses/` in the APK:

- `kotlinx-coroutines-NOTICE.txt` — coroutines 1.8.1, JetBrains and contributors.
- `kotlinx-serialization-NOTICE.txt` — serialization 1.9.0, JetBrains and authors.
- `Kotlin-ThreeTenBP-BSD-3-Clause.txt` — Kotlin 2.2.10 embedded time code,
  copyright Stephen Colebourne and Michael Nascimento Santos.
- `Kotlin-Boost-1.0.txt` — Kotlin JVM math; its machine-object-code exception
  is recorded accurately, and its full text is retained.

AndroidX graphics-path 1.0.1 supplies native libraries for four ABIs; each matches
the official AAR. Its AOSP native source carries Apache-2.0 headers and does not
bundle/link a separate Skia library. `docs/FDROID_NATIVE.json` records hashes
and source provenance; no independent native rebuild is claimed. A trusted
repository is supporting provenance, not a replacement for license review.

Google Play Review is restricted to the Play flavor and absent from the F-Droid
runtime graph and APK. The official build recipe also removes those unused
store-only source declarations before the source scan.

The icon is user-supplied Mandaza artwork. Luke confirmed redistribution and
inclusion under MIT on November 4, 2026; its density derivatives share those terms.
The confirmation is tracked in `docs/FDROID_PROVENANCE.md`. Listing screenshots
are actual Android captures with dated device records and matching hashes.
System fonts are used; no font file is bundled. The app's MIT file does not
establish a separate third-party artwork grant.
