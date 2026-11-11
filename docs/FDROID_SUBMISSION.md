## Abstract for new app inclusion

### Functions and usage

Mandaza draws animated hexagonal-loop art on Android phones and tablets.
Choose from twelve palettes, tune the geometry, save favorites and export PNG
wallpaper, or use the art as a backdrop for an ambient clock. The deterministic
engine runs on the device. Microphone response is optional and off by default.
It reads live sound levels without saving audio recordings.

This contribution adds only `metadata/app.mandaza.android.yml`. The upstream
`en-US` Fastlane listing includes an icon, three real Android screenshots and
a changelog. TV and Wear have independent identities and are outside this MR.

![Canvas](https://raw.githubusercontent.com/lukeslp/mandaza-android/fdroid-v1.3.6/fastlane/metadata/android/en-US/images/phoneScreenshots/01-live-canvas.png)
![Ambient clock](https://raw.githubusercontent.com/lukeslp/mandaza-android/fdroid-v1.3.6/fastlane/metadata/android/en-US/images/phoneScreenshots/02-zen-clock.png)
![Settings](https://raw.githubusercontent.com/lukeslp/mandaza-android/fdroid-v1.3.6/fastlane/metadata/android/en-US/images/phoneScreenshots/03-tune.png)

### Purpose and project history

Mandaza combines deterministic hexagonal-loop art, saved patterns, wallpaper
export and an adjustable ambient clock in one native app. The same seed and
settings recreate a pattern, so a favorite can be used again as art or a clock
backdrop. These are the features proposed here; no exhaustive comparison with
other F-Droid apps is claimed.

Native Android development began July 18, 2026. The public repository was
created on November 5 as a complete Android phone/core source export from the
existing multi-platform project. Its short public Git history reflects that
export, not the start of app development. The original multi-platform repository
remains private; the public export contains the full inputs needed for this build.

## Source and licensing

The Android phone/core source is licensed under MIT, with upstream notices
preserved. The loop construction adapts Dillon (Dillo)'s explicitly MIT-licensed family; Mash
ancestry includes GRC's public-domain release and Baagoe's MIT code. The
supplied launcher artwork is included under MIT with the author's permission.
The runtime inventory covers all 96 resolved coordinates, 63 official binary
artifacts/source archives and four AndroidX graphics-path native libraries.
Applicable Apache, BSD and Boost material is included. The upstream docs and
the APK's license assets document these origins.

## Build and signing

Version 1.3.6 (10311), minimum API 24, target API 36. JDK 21, Gradle 8.14.3,
AGP 8.13.0, Kotlin 2.2.10. The prebuild runs in a disposable source copy and
removes unused store-only sources/declarations. No scanner exceptions are
used to conceal code. The F-Droid runtime contains no direct updater, Play
Review or Internet permission.

`Binaries` and `AllowedAPKSigningKeys` use the established upstream direct
signer. Clean macOS/F-Droid and independent Linux unsigned outputs match,
and F-Droid's signature-copy verification passes against the upstream
APK. Play App Signing compatibility is not assumed. The release's
`REPRODUCIBILITY.json` identifies exact source/artifact hashes.

Updates are initially manual while the Android-only release/tag/version-code
policy is established. This avoids automatically selecting a version from
another distribution flavor.
Only the latest version is proposed. No external source submodules are needed.

## Validation

- fdroidserver 2.4.5 local build plus source/APK scans: pass.
- Metadata read/rewrite/lint: pass.
- Twelve JVM tests: pass; Android lint: zero errors, 22 explained warnings.
- Seven AOSP/API 36 functional/ATF cases at normal and 200% text, plus a tablet
  layout fixture: pass. Native keyboard navigation and denied microphone included.
- Production-key 1.3.5 to 1.3.6 fixture upgrade: pass, favorite/history retained.
- Seven automated cases pass on each physical Pixel 9a and Pixel 10 (API 37),
  using a separate test app with the release configuration. Existing 1.3.5
  installations remain in place.
- Manual TalkBack speech/traversal and physical flip-cover behavior are not claimed.

The 22 retained Android lint warnings comprise 15 launcher-icon shape/duplicate
warnings, four available dependency updates, one newer-target-API suggestion,
one attribute ignored below API 26, and one explicit touchscreen requirement.
Existing artwork, audited dependency pins, API 36 targeting and the phone/tablet
scope are retained; no lint suppression was added.

The [public source](https://github.com/lukeslp/mandaza-android/tree/f3645dd1fd2a5210eb3e060edbe34c1e3527562d)
and [signed release](https://github.com/lukeslp/mandaza-android/releases/tag/fdroid-v1.3.6)
are available. Anonymous downloads match SHA256SUMS.txt. The
[public Linux CI run](https://github.com/lukeslp/mandaza-android/actions/runs/42004282746)
passes. A fresh fdroidserver build from that public source fetched the public
`Binaries` APK, reproduced it and verified the allowed upstream signer.
The author reviewed the app on both Pixels and approved source/release publication.

The [fork pipeline](https://gitlab.com/lukeslp/fdroiddata/-/pipelines/3031287664)
and the new [merge-request pipeline](https://gitlab.com/lukeslp/fdroiddata/-/pipelines/3033945595)
both stopped at GitLab's account identity-verification gate before any jobs ran. The UI labels the pipeline failed/yaml invalid
and displays the identity-verification requirement. No fork CI job has passed.
Maintainer CI and official builder acceptance remain pending. Please trigger the
F-Droid project pipeline if possible. No phone or payment details have been
submitted to unlock fork runners, in line with this repository's MR template.

The universal APK is 12,221,324 bytes. Its only native payload is the four
AndroidX graphics-path libraries, 37,392 bytes in total, so ABI splitting would
not materially reduce this release's download size.


## Checklist

### Policy

* [x] The app complies with the [inclusion policy](https://f-droid.org/docs/Inclusion_Policy). _Pay special attention to Quality point 6._
* [x] The original app author has been notified (and does not oppose the inclusion). If you are not the author, please paste the link of the reply from the author.
* [x] The upstream app source code repo contains the app metadata in a [Fastlane](https://gitlab.com/snippets/1895688) or [Triple-T](https://gitlab.com/snippets/1901490) folder structure. The summary and description must be included and images, icon, and changelog should also be provided for better user experience. The `en-US` locale must be included.

### Docs

* [x] Please read [the guide](https://gitlab.com/fdroid/fdroiddata/-/blob/master/CONTRIBUTING.md) first if this is your first contribution.
* [x] Please make sure your metadata follows the best practice in [our templates](https://gitlab.com/fdroid/fdroiddata/tree/master/templates).
* [x] Please read the [Build Metadata Reference](https://f-droid.org/docs/Build_Metadata_Reference/) and make sure your metadata is valid.
* [x] Please read the [Quick Start Guide](https://f-droid.org/en/docs/Submitting_to_F-Droid_Quick_Start_Guide/).

### Merge Request Setup

* [x] The title of this merge request should follow "New app: app name" format.
* [x] Please make sure your fdroiddata fork is public and your branch is not protected. See <https://docs.gitlab.com/user/project/repository/branches/protected/>.
* [x] Please read [our Git guide](https://gitlab.com/fdroid/wiki/-/wikis/Tips-for-fdroiddata-contributors/Git-Usage) if you don't know how to rebase your branch. Don't rebase your branch if there is no conflict.
* [x] All related [fdroiddata](https://gitlab.com/fdroid/fdroiddata/issues) and [RFP issues](https://gitlab.com/fdroid/rfp/issues) have been referenced in this merge request. Searches found no related Mandaza issues or merge requests on November 5, 2026.
* [x] Please only submit one app in one MR.

### Metadata

* [x] Metadata must be put in `metadata/<applicationId>.yml`.
* [x] Metadata must be a valid YAML file.
* [x] Metadata must use LF as line ending.
* [x] Don't add summary/description/changelog/images or anything that should be provided in upstream repo. Please check the Changes tab to make sure there is no other unrelated files added in the MR.
* [x] Releases are tagged and auto update is enabled unless there is a special reason. Manual updates are intentional for this first Android-only export; the reason is recorded above and in MaintainerNotes.
* [x] There is an issue tracker and contact info of the author so that we can report bugs and contact the author.
* [x] An AuthorName must be added. It doesn't need to be the real name.
* [x] External repos are added as git submodules instead of srclibs. No external source repositories are required by this recipe. You can update git submodules without opening an MR in this repo and the submodule is covered by our scanner.
* [x] Enable [Reproducible Builds](https://f-droid.org/docs/Reproducible_Builds). We'll use your signature for improved security/reliability, also allowing users to switch between different channels. Do note that if you don't enable reproducible build then the apk will be signed with our key so you can't enable it later. If you can't enable this, please add the reasons here.
* [x] Setup abi split if the APK is large and the splitted ones can be much smaller. Not applicable here: all four native libraries total 37,392 bytes; see the size note above.
* [x] Only the latest versions should be kept in the metadata before it's merged. If you update the metadata, please replace the old versions with the new ones.
* [x] Don't add any disabled versions in the metadata.
* [x] The `commit` field should be the full hash. Please don't use tag or branch in commit.

### Pipeline

* [ ] All pipelines should pass. Fork CI has zero jobs because of the account identity gate described above; public Linux CI and local fdroidserver verification pass.
* [x] All warnings and errors in the Reports tab should be fixed or explained. The fork created no job reports; its identity gate and the 22 Android lint warnings are explained in the validation notes.
* [x] F-Droid CI runners are under GitLab's FOSS program, so there's no need for you to pay for any CI time. If Gitlab starts asking for phone numbers or credit cards don't submit anything, just leave a note in the MR so we know we need to trigger the CI.
