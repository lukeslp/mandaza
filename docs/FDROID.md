# Official F-Droid preparation — November 4, 2026

Status: **provenance reviewed; candidate built and AOSP-tested; not submitted or published**.
This is preparation for the official catalog, separate from Luke's existing
independent binary repository. Source remains private.

## Candidate and scope

- Phone/tablet package: `app.mandaza.android`.
- Unreleased F-Droid version: **1.3.6 (10311)**; minimum API 24, target 36.
- Dedicated `fdroid` flavor: no direct updater, Google Play Review dependency
  or Internet permission. Optional microphone responsiveness starts off.
- Existing direct 1.3.5 (10310), Play (10305), Amazon (10308), TV and Wear
  identities are unchanged. No new signing identity was created.
- Kotlin/JVM 17 bytecode, JDK 21, SDK/build-tools 36, AGP 8.13.0, Kotlin
  2.2.10, checksum-pinned Gradle 8.14.3.

The local release build is deliberately unsigned; F-Droid must not need a
private signing key. Choose the catalog signing route before the first public
artifact. The ordinary F-Droid key cannot update an existing differently signed
installation. Reproducible upstream-signed publication is an alternative that
must be demonstrated, and does not automatically match Google Play App Signing.

## Build and artifact verification

In `android/`, with JDK 21 and `ANDROID_HOME` configured:

```sh
./gradlew --no-daemon --console=plain \
  :core:testDebugUnitTest :app:testFdroidDebugUnitTest \
  :app:lintFdroidRelease :app:assembleFdroidRelease
./gradlew --console=plain :app:dependencies \
  --configuration fdroidReleaseRuntimeClasspath > fdroid-dependencies.txt
```

`fdroid/prepare-build.py --confirm-build-sandbox` runs only on a disposable
source/build copy. It removes unused store-only source and dependency
declarations for source scanning, and restricts the builder to phone/core.
It does not alter the development checkout's direct/Play/Amazon functionality.

`fdroid/verify-apk.py` checks the actual release identity, no debug flag,
permission allowlist, SDK-bounded legacy storage, packaged license material,
unsigned output, and the resolved dependency/DEX reports. Runtime checks reject
Play Review, Play Services, ML Kit and Firebase namespaces. The official
fdroidserver scanner is an additional independent check, not replaced by this
small project-specific verifier.

The Linux workflow `.github/workflows/android-fdroid.yml` pins its GitHub and
Android SDK setup actions and uses read-only repository permissions. It builds without
release credentials, tests, lints and retains the unsigned APK/check evidence.
Its eventual result is distinct from acceptance by F-Droid's own builder.

## Evidence and remaining gates

Measured on Napoleon: the candidate passed six core tests and six app tests,
lint with zero errors (22 warnings), release/debug builds, resolved runtime and
DEX checks with no excluded SDK namespaces. An independent disposable source
export at `18b03f4` also passed its clean build, tests and lint. F-Droid's
fdroidserver 2.4.5 source and final APK scanners each reported zero problems;
metadata read/rewrite/lint passed with current fdroiddata category configuration.
The source export's secret scan reported zero findings. The APK's required
license assets are verified. All 96 resolved runtime coordinates have cached
POM license metadata, including an inherited Guava license; this is supporting
evidence, not a finished native-source/asset provenance audit.

The APK has no Internet permission. Its
storage permissions are limited to API 28 and earlier; microphone is optional.
AndroidX's `libandroidx.graphics.path.so` is present for four ABIs; do not
describe the APK as containing no native code.

The exact source snapshot, APK hash, logs and Linux CI results are recorded in
the private preparation handoff under `artifacts/fdroid-preparation/`. Local
builds do not prove reproducibility or Google-free physical-device acceptance.

The extended review is recorded in [FDROID_PROVENANCE.md](FDROID_PROVENANCE.md),
[FDROID_COMPONENTS.json](FDROID_COMPONENTS.json) and
[FDROID_NATIVE.json](FDROID_NATIVE.json). Dillon's explicit per-Pen MIT grants,
GRC's public-domain release, Baagøe's MIT, the two kotlinx NOTICEs and Kotlin's
embedded ThreeTenBP/Boost licenses are preserved. Luke confirmed the supplied
icon and derivatives may be included under MIT on November 4, 2026.

Six instrumented AOSP/API 36 acceptance cases cover pattern/history/favorite
restoration, Zen exit, selected palette semantics, PNG export, the oldest
history entry, and denied optional microphone access. They run with Android's
Accessibility Test Framework, using an explicit disposable-debug-data opt-in.
The fixture contains no Play Services, Google Services Framework or Play Store.
Full TalkBack speech/traversal and physical flip folding remain distinct,
unperformed checks; automated semantics/ATF must not be described as those.
The larger-text rerun, exact final source export/build/scans and refreshed
Linux CI are recorded in the private final handoff when completed.

Before official submission:

- Review the exact public source export; do not expose private history by
  changing repository visibility. The existing repository remains private.
- Preserve the completed attribution, asset grant and runtime/native inventory
  in the exact exported source and APK; the verifier compares notice bytes
  and native hashes with the reviewed source.
- Repeat official source/metadata/build checks against the final reviewed
  public tag in F-Droid's own build environment. Local scanner and metadata
  success does not establish acceptance by the catalog's builder.
- Decide signing/update continuity, approve the exact source release/tag,
  and replace the disabled draft build's pin with the reviewed public release.
- Retain final AOSP functional/permission/ATF, larger-text and update-data
  receipts. Finish a human TalkBack/keyboard acceptance pass for broader release
  confidence; do not promote automated checks into manual-access claims.
- Submit an fdroiddata merge request or packaging request and respond to
  maintainers. Submission is not acceptance or publication.

The English listing uses Android-specific claims and reuses existing real
Android screenshots. It makes no full flip-cover claim. The cover direction is
clock/ambient through Zen, documented in [ANDROID_COVER.md](ANDROID_COVER.md).

## References

- https://f-droid.org/en/docs/Inclusion_Policy/
- https://f-droid.org/en/docs/Build_Metadata_Reference/
- https://f-droid.org/en/docs/Reproducible_Builds/
- https://f-droid.org/en/docs/All_About_Descriptions_Graphics_and_Screenshots/

## Handoff and rollback

Source worktree: `/Users/luke/workspace/mandaza-fdroid-20261104`, branch
`codex/mandaza-fdroid-20261104`, based on clean `63d791b`. Original appcat
checkout was preserved. Private evidence is under
`artifacts/fdroid-preparation/` and is not committed or uploaded as source.
Revert this branch's preparation commits to remove the new flavor, checks,
metadata and workflow; no live distribution or service needs rollback.

`fdroid/export-source.py --ref <commit> --output <new-directory>` creates a
reviewable Android-only source tree from committed inputs. It excludes private
history and non-phone modules, keeps complete phone/core source and notices,
replaces the Apple build file with its marketing-version input, and records
file hashes/transforms in `SOURCE_EXPORT.json`. It never publishes. Run the
exact export through its own build and scans before approving a public tag.
