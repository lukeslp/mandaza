# Attribution and dependency review

Mandaza's first-party code is MIT licensed; see `LICENSE`. Luke Steuber's
author credit is retained. This inventory does not relicense third-party work.

## Seeded random generator

The native engines identify the seeded generator as Alea/Mash. Its coefficients
and procedure correspond to Johannes Baagøe's Mash algorithm. Preserve the
2010 copyright and MIT terms in `LICENSES/Johannes-Baagoe-MIT.txt` with source
distributions and APK license material. The algorithm is adapted, not a bundled
JavaScript runtime.

Primary reference and original notice:
https://github.com/davidbau/seedrandom/blob/released/lib/alea.js

## Geometry attribution review

The existing README credits Charlotte Dann's Hexagonal Generative Art and
David Siaw's Hexlife. Those credits are retained. CodePen's public-Pen MIT rule
is documented at https://blog.codepen.io/documentation/licensing/ and the
referenced work at https://codepen.io/pouretrebelle/pen/ZBNJmd.

Before the public source release, trace the native loop implementation to the
exact source/export used and preserve every applicable original notice. The
general platform license policy alone does not finish that provenance review.
The README's Truchet-mathematics attribution is not a claim that a modern
implementation is public domain.

## Android runtime dependencies

The F-Droid flavor uses AndroidX/Compose, Kotlin/serialization and their
resolved transitive dependencies. Their package source and license notices
need to be retained according to their upstream terms. The candidate dependency
report and APK class scan are in the private preparation evidence. Google Maven
as a repository is not itself a proprietary runtime dependency.

Google Play Review is restricted to the Play flavor and absent from the F-Droid
runtime graph and APK. The official build recipe also removes those unused
store-only source declarations before the source scan.

The current icon and real Android screenshots are reused from the existing
Android listing. Confirm asset provenance as part of the exact public-source
packet review; a filename or an app-level license is not substitute evidence.
