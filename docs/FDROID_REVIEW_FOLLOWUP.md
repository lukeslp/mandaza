# Proposed MR !55922 follow-up

Status: prepared locally, not posted. Luke's confirmation is required before
posting this comment to the third-party F-Droid repository. It changes no recipe,
source pin, tag, version, signing key or release asset.

Target: <https://gitlab.com/fdroid/fdroiddata/-/merge_requests/55922>

---

Follow-up verification for the unchanged 1.3.6 (10311) release:

- [Public Linux run 42118994931](https://github.com/lukeslp/mandaza-android/actions/runs/42118994931) checks out the pinned `fdroid-v1.3.6` source, runs tests/lint/APK checks and compares its source commit, tag and unsigned APK digest against the published receipt. It passed. The unsigned SHA-256 remains `4e9d12e0f63f1be7461f1f9c13925bc8136a715cd65dc34bf854ab77999c11b0`.
- The exact signed release APK, SHA-256 `db95b1c95edeedd9426102a0ebebdf394985bace0df28e3231946dc47651425e`, now upgrades the existing 1.3.5 (10310) app in place on both Pixel 9a and Pixel 10, API 37. Pulled installed APKs match the release. Both release activities resume without an observed app crash. App identity, first-install record and credential-data directory remain; no uninstall or reset was used. Individual personal favorites/history were not extracted.
- These exact-release upgrade/launch checks are separate from the earlier seven-case debug-review tests. Full human TalkBack traversal, physical Fire/fold behavior and 16KB-device acceptance are still not claimed.

The submitted recipe, pinned source, release tag, signed assets and allowed
signer remain unchanged. The initial manual-update policy also remains unchanged.
[Upstream verification notes](https://github.com/lukeslp/mandaza-android/blob/main/docs/RELEASE_VERIFICATION.md)
keep upstream CI separate from official F-Droid builder acceptance.

The fork pipeline still ran zero jobs at GitLab's account identity gate. Please
trigger the F-Droid project CI when possible. No phone or payment details have
been submitted to unlock fork runners.
