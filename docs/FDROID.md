# Official F-Droid preparation — November 4, 2026

Status: **local candidate built and checked; not submitted or published**.
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

The Linux workflow `.github/workflows/android-fdroid.yml` is pinned to official
action revisions and uses read-only repository permissions. It builds without
release credentials, tests, lints and retains the unsigned APK/check evidence.
Its eventual result is distinct from acceptance by F-Droid's own builder.

## Evidence and remaining gates

Measured on Napoleon: the initial candidate passed six core tests and six app
tests, lint with zero errors (22 warnings), release/debug builds, resolved
runtime and DEX checks with no excluded SDK namespaces, and fdroidserver 2.4.5's
binary scanner with zero problems. The APK has no Internet permission. Its
storage permissions are limited to API 28 and earlier; microphone is optional.
AndroidX's `libandroidx.graphics.path.so` is present for four ABIs; do not
describe the APK as containing no native code.

The final source snapshot, license-asset verification, source scan, clean-copy
build and Linux CI results are recorded in the preparation handoff. Local
builds do not prove reproducibility or Google-free physical-device acceptance.

Before official submission:

- Review the exact public source export; do not expose private history by
  changing repository visibility. The existing repository remains private.
- Finish the geometry attribution/source mapping and asset rights inventory.
  The seeded Mash notice is restored in `LICENSES/` and the F-Droid APK.
  See `THIRD_PARTY_NOTICES.md`; an app-level MIT file does not cover every import.
- Confirm the complete runtime dependency/native-library license inventory.
- Pass the source scanner on the recipe-prepared source, a clean Linux build,
  and the current fdroiddata metadata/build checks.
- Decide signing/update continuity, approve the exact source release/tag,
  and replace the disabled draft build's pin with the reviewed public release.
- Verify core tasks, update/data retention, microphone-off behavior and
  accessibility without Google services. No such device claim is made yet.
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
