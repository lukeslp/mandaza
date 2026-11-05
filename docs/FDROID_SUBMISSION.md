## Mandaza

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

The [public source](https://github.com/lukeslp/mandaza-android/tree/f3645dd1fd2a5210eb3e060edbe34c1e3527562d)
and [signed release](https://github.com/lukeslp/mandaza-android/releases/tag/fdroid-v1.3.6)
are available. Anonymous downloads match SHA256SUMS.txt. The
[public Linux CI run](https://github.com/lukeslp/mandaza-android/actions/runs/42004282746)
passes. A fresh fdroidserver build from that public source fetched the public
`Binaries` APK, reproduced it and verified the allowed upstream signer.
The author reviewed the app on both Pixels and approved source/release publication.

The [fork pipeline](https://gitlab.com/lukeslp/fdroiddata/-/pipelines/3031287664)
created zero jobs because GitLab requires additional identity verification
before running CI on this account. The UI labels the pipeline failed/yaml invalid
and displays the identity-verification requirement. No fork CI job has passed.
Maintainer CI and official builder acceptance remain pending.
