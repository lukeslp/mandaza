# F-Droid provenance review — November 4, 2026

Source publication and catalog acceptance are separate from this audit.
First-party code remains MIT, copyright Luke Steuber. The Android port entered
at `8924c9c`; its Swift precursor entered at `900c8fd` on May 10, 2026.

## Geometry and Mash source

The concrete source family is Dillon (Dillo)'s
[Controlled loops on hexagons](https://codepen.io/Dillo/details/NWPWoYO), based
on [Loops on hexagons](https://codepen.io/Dillo/details/xvXjLZ). Both Details
pages explicitly display full MIT grants with `Copyright (c) 2026 by Dillon`
and the respective Pen URL. The works were created in 2019; 2026 is the
currently displayed notice, not a guessed creation date. Full notices are in
`LICENSES/` and the F-Droid APK.

| Distinctive operation | Controlled loops JS | Native Kotlin |
| --- | --- | --- |
| Seven weighted point-count rows | 15–21 | `probabilityTable` |
| Fractions 3/8, 5/8, 9/32, 1/2, 23/32 | 230–236 | side-point placement |
| Regularity above five scaled by 95/5 | 539 | `internalRegularity` |
| Opposite-parity random partner | 555 | pairing selection |
| Split interval, discard endpoints, preserve interior | 264–269 | `connectables` partition |

An archived Mandaza HTML renderer preserves the Cell/Dot/Loop topology used by
the native ports. The base Pens instead use integer crossings; one vertex
control factor changes from 0.78 to 0.6. These are adaptations. The exact
historical intermediary export is not recorded, so no unchanged upstream
snapshot or complete forensic history is claimed. The explicit MIT grants
and preserved attribution cover the identified source family.

The later [jigsaw derivative](https://codepen.io/Dillo/details/YzEdJKv) links the
controlled version and corroborates the family; its jigsaw effects are absent.
Charlotte Dann's previously linked Pen uses a different creator/destroyer-agent
system. It is a related artistic reference, not the demonstrated pairing source.

Dillon's generator cites [GRC](https://www.grc.com/otg/uheprng.htm). Its
[primary source](https://www.grc.com/js/uheprng.js) expressly releases code and
derivatives into the public domain and credits Johannes Baagøe. Native code
preserves the small Mash variant/wrapper, not the 48-word UHEPRNG/MWC engine or
entropy APIs. The independent Baagøe MIT notice is preserved along with GRC's
release and Dillon's MIT grants. Native Unicode handling is an adaptation.

## Runtime and native inventory

[FDROID_COMPONENTS.json](FDROID_COMPONENTS.json) covers all 96 resolved runtime
coordinates: 63 binary AAR/JAR artifacts and 33 metadata-only modules. All
metadata and binary hashes/bytes match official Google Maven/Maven Central
origins. Published source JARs were fetched and inspected for all 63 binaries.
Test/compiler-only dependencies are not confused with shipped APK contents.

The audit restored two supplied kotlinx Apache NOTICEs and the BSD-3-Clause
notice for ThreeTenBP-derived code in Kotlin stdlib's `kotlin.time`. Its Boost
math license is retained too; the machine-code exception is recorded accurately.
The POM's principal Apache declaration alone did not reveal those portions.
Kotlin's separate Compiler NOTICE is not asserted to be a stdlib-runtime notice.

All four graphics-path 1.0.1 libraries match the official AAR. Release source
revision `8a05a22af450d589ef911d772a001a49dcb05b71` has three CMake inputs and
local headers carrying AOSP Apache-2.0 notices. Its four ELF dependency lists
contain only system libc/libdl/libm. No separate Skia library or extra BSD/EPL
native component was found. Native compilation to identical bytes was not
attempted. Freely licensed trusted-Maven prebuilts are permitted by the current
[inclusion policy](https://f-droid.org/en/docs/Inclusion_Policy/).
[FDROID_NATIVE.json](FDROID_NATIVE.json) records exact native hashes/source URLs.

The APK verifier compares every required notice byte-for-byte with reviewed
source files. Final rebuild/scanner outcomes belong in the preparation handoff.
The audited release dependency graph predates the new test-only dependencies;
no runtime dependency replacement is proposed.

## Assets

| Asset | Origin | Rights/evidence status |
| --- | --- | --- |
| Launcher/listing icon and density derivatives | User-provided art at `243eb9f`; Android icon restoration `c3725e4` | Luke explicitly confirmed redistribution and MIT inclusion on November 4, 2026. |
| F-Droid phone screenshots | Fresh, uncomposited captures from the candidate's instrumented AOSP/API 36 acceptance run on November 5, 2026 | `FDROID_SCREENSHOTS.json` records the device, variant and image hashes; they supersede the older Play captures for this listing. |
| Generated patterns | Reviewed engine and first-party palettes/rendering | No separate stock artwork or remote executable payload bundled. |
| Fonts | Android system sans; no packaged font file | No bundled font license needed. |
| Material icons | AndroidX Material Icons dependency | Apache-2.0; runtime matrix and license bundle. |

A public source release must contain complete Android build inputs and these
notices/inventories. Publishing private Git history is unnecessary and is not
authorized by this audit itself. Private fetched evidence and comparisons stay
under ignored `artifacts/fdroid-provenance/`.
