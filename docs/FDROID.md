# Official F-Droid preparation (November 4, 2026)

**Source and signed release published November 5, 2026. The F-Droid MR awaits
confirmation.** Luke reviewed the separate test app on both Pixels and approved
publication.
This is preparation for the official catalog, separate from the independent
binary repository. The original multi-platform repository remains private.

- Public Android source: https://github.com/lukeslp/mandaza-android
- Published tag: `fdroid-v1.3.6`, commit `f3645dd1fd2a5210eb3e060edbe34c1e3527562d`.
- Signed release: https://github.com/lukeslp/mandaza-android/releases/tag/fdroid-v1.3.6
- Public CI: https://github.com/lukeslp/mandaza-android/actions/runs/42004282746 (passed).
- Proposed one-file diff: https://gitlab.com/lukeslp/fdroiddata/-/compare/master...app.mandaza.android?from_project_id=36528

Anonymous source/tag/download checks pass. A fresh fdroidserver 2.4.5 build
from public source fetched the published Binaries APK, reproduced it and
verified the allowed upstream signer. GitLab requires additional identity
verification before fork CI can run, so its pipeline created zero jobs.
Maintainer CI and official builder acceptance remain pending.

## Release scope

- Phone/tablet package: `app.mandaza.android`.
- Published F-Droid candidate: **1.3.6 (10311)**; minimum API 24, target 36.
- Dedicated `fdroid` flavor: no direct updater, Google Play Review dependency
  or Internet permission. Optional microphone responsiveness starts off.
- Existing direct 1.3.5 (10310), Play (10305), Amazon (10308), TV and Wear
  identities are unchanged. No new signing identity was created.
- Kotlin/JVM 17 bytecode, JDK 21, SDK/build-tools 36, AGP 8.13.0, Kotlin
  2.2.10, checksum-pinned Gradle 8.14.3.

Source builds remain unsigned and require no private key. Luke chose
upstream-signed reproducible builds. The published APK uses the established
direct-download certificate and passes F-Droid signature reproduction. A
production-key 1.3.5 to 1.3.6 upgrade on disposable AOSP retains favorite/history
state. Google Play App Signing compatibility has not been established.

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
declarations for source scanning and restricts the builder to phone/core.
It does not alter the development checkout's direct/Play/Amazon functionality.

`fdroid/verify-apk.py` checks the actual release identity, no debug flag,
permission allowlist, SDK-bounded legacy storage, packaged license material,
unsigned output, and the resolved dependency/DEX reports. Runtime checks reject
Play Review, Play Services, ML Kit and Firebase namespaces. The official
fdroidserver scanner is an additional independent check, not replaced by this
small project-specific verifier.

The Linux workflow `.github/workflows/android-fdroid.yml` pins its GitHub and
Android SDK setup actions and uses read-only repository permissions. It builds
without release credentials, runs tests and lint, and retains the unsigned APK
and check results. A passing workflow does not establish acceptance by
F-Droid's own builder.

## Validation and remaining checks

Measured on the final candidate: six core and six app JVM tests pass; lint has
zero errors and 22 warnings. Release/debug/test builds pass, and the actual
release identity, permissions, DEX exclusions, four native-library hashes and
all eleven notice assets pass the project verifier. The 96-coordinate runtime
graph is unchanged from the reviewed inventory. Linux CI and the independent
source export/build/scans are recorded by exact revision in the final handoff.

The APK has no Internet permission. Storage permissions apply only to API 28
and earlier; microphone access is optional. The APK includes native code:
AndroidX's `libandroidx.graphics.path.so` is present for four ABIs.

The exact source snapshot, APK hash, logs and Linux CI results are recorded in
the private final handoff under `artifacts/fdroid-provenance/`. Local
builds do not prove official-builder reproducibility or physical-device acceptance.

The extended review is recorded in [FDROID_PROVENANCE.md](FDROID_PROVENANCE.md),
[FDROID_COMPONENTS.json](FDROID_COMPONENTS.json) and
[FDROID_NATIVE.json](FDROID_NATIVE.json). Dillon's explicit per-Pen MIT grants,
GRC's public-domain release, Baagøe's MIT, the two kotlinx NOTICEs and Kotlin's
embedded ThreeTenBP/Boost licenses are preserved. Luke confirmed the supplied
icon and derivatives may be included under MIT on November 4, 2026.

Seven instrumented AOSP/API 36 acceptance cases cover pattern/history/favorite
restoration, Zen exit, selected palette semantics, PNG export, the oldest
history entry, keyboard canvas activation and ordered footer navigation, and
denied optional microphone access. They run with Android's
Accessibility Test Framework, using an explicit disposable-debug-data opt-in.
The fixture contains no Play Services, Google Services Framework or Play Store.
Full TalkBack speech/traversal and physical flip folding remain untested.
Automated semantics/ATF results do not establish either.
All seven cases pass at normal and 200% font size, and in an AOSP tablet-size
layout fixture (1600×2560, density 240). The latter uses a display override on
the isolated emulator, not a physical tablet. A same-debug-signer
10310→10311 fixture checks persistent seed, favorites, history and settings;
it does not establish production signer compatibility. Color-space simulation,
exact final source export/build/scans and refreshed Linux CI receipts belong
in the private final handoff.

Before official submission, obtain Luke's confirmation for the exact fork diff
and `submission/MR_DESCRIPTION.md`. The fork commit is
`35b53dfaf941d63bd983ec7de39d50dd663371e1`; its raw metadata matches the locally
validated recipe byte-for-byte. Disclose the GitLab CI identity gate.
Keep the manual update policy, preserved attribution and exact public pins.
Respond to maintainers after submission; submission does not establish catalog
acceptance. Full human TalkBack speech/traversal and physical flip/tablet
checks are still not claimed. Preserve both Pixel test copies and user data.

Luke requires confirmation immediately before any submission to a third-party
repository. Prepare the exact source/tag, recipe diff, validation and submission
text for review first. GitLab sign-in is not submission approval.

The English listing uses Android-specific claims and fresh, uncomposited AOSP
phone screenshots; `FDROID_SCREENSHOTS.json` records their origin and hashes.
It makes no full flip-cover claim. The planned cover experience is an ambient
clock using Zen, documented in [ANDROID_COVER.md](ANDROID_COVER.md).

## References

- https://f-droid.org/en/docs/Inclusion_Policy/
- https://f-droid.org/en/docs/Build_Metadata_Reference/
- https://f-droid.org/en/docs/Reproducible_Builds/
- https://f-droid.org/en/docs/All_About_Descriptions_Graphics_and_Screenshots/

## Handoff and rollback

Source worktree: `/Users/luke/workspace/mandaza-fdroid-20261104`, branch
`codex/mandaza-fdroid-20261104`, based on clean `63d791b`. Original appcat
checkout was preserved. Private evidence is under
`artifacts/fdroid-preparation/` and `artifacts/fdroid-provenance/` and is not
committed or uploaded as source.
Revert this branch's preparation commits to remove the new flavor, checks,
metadata and workflow. The published source tag and signed APK remain
immutable; future fixes need a new reviewed release. No production service
was changed.

`fdroid/export-source.py --ref <commit> --output <new-directory>` creates a
reviewable Android-only source tree from committed inputs. It excludes private
history and non-phone modules, keeps complete phone/core source and notices,
replaces the Apple build file with its marketing-version input, and records
file hashes/transforms in `SOURCE_EXPORT.json`. It never publishes. Run the
exact export through its own build and scans before approving a public tag.
