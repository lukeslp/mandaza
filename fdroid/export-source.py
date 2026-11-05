#!/usr/bin/env python3
"""Prepare a complete Android-only source review tree without private history.

Exports only committed inputs. This creates local files; it never publishes,
changes repository visibility or copies signing material.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--ref", default="HEAD")
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]

def git(*arguments):
    return subprocess.check_output(["git", "-C", str(root), *arguments])

revision = git("rev-parse", "--verify", args.ref + "^{commit}").decode().strip()
version_text = git("show", revision + ":project.yml").decode()
version = re.search(r'MARKETING_VERSION:\s*"?([0-9]+(?:\.[0-9]+){0,2})', version_text)
assert version, "Marketing version missing"
inputs = [
    "android/app", "android/core", "android/build.gradle.kts",
    "android/settings.gradle.kts", "android/gradle.properties", "android/gradle",
    "android/gradlew", "android/gradlew.bat", "LICENSE", "LICENSES",
    "THIRD_PARTY_NOTICES.md", "fastlane", "fdroid/prepare-build.py",
    "fdroid/verify-apk.py", "fdroid/metadata", "docs/FDROID_PROVENANCE.md",
    "docs/FDROID_COMPONENTS.json", "docs/FDROID_NATIVE.json",
    "docs/FDROID_SCREENSHOTS.json", ".github/workflows/android-fdroid.yml",
]
archive = git("archive", "--format=tar", revision, "--", *inputs)
destination = args.output.resolve()
assert not destination.exists(), "Choose a new output directory"
with tarfile.open(fileobj=io.BytesIO(archive)) as source:
    for member in source.getmembers():
        assert member.isdir() or member.isfile(), "Linked/special input requires review"
        assert not member.name.endswith((".jks", ".keystore", "/local.properties", "/keystore.properties", "/.env")), "Private build input rejected"
    destination.mkdir(parents=True)
    source.extractall(destination, filter="data")

(destination / "project.yml").write_text(
    '# Android export: marketing-version input only; no Apple build configuration.\n'
    f'MARKETING_VERSION: "{version[1]}"\n'
)
(destination / ".gitignore").write_text(
    '**/build/\n**/.gradle/\n**/.kotlin/\n**/local.properties\n'
    '**/keystore.properties\n*.jks\n*.keystore\nartifacts/\n__pycache__/\n*.pyc\n'
)
settings = destination / "android/settings.gradle.kts"
settings.write_text(settings.read_text().replace(
    'include(":core", ":app", ":wear", ":tv")', 'include(":core", ":app")',
))
(destination / "README.md").write_text("""# Mandaza for Android

Animated hexagonal art, favorites, PNG export and a customizable ambient clock.
This source release covers the native phone/tablet app and core engine.
The F-Droid flavor is entirely on-device, with no account, analytics, direct
updater, Play Review runtime or Internet permission. Microphone response is
optional and starts off. Full-panel flip-cover behavior is not yet verified.

## Build

Use JDK 21, Android SDK 36/build-tools 36.0.0 and the checksum-pinned wrapper.
In a disposable clone, prepare and build the F-Droid flavor:

```sh
python3 fdroid/prepare-build.py --confirm-build-sandbox
cd android
./gradlew :core:testDebugUnitTest :app:testFdroidDebugUnitTest :app:lintFdroidRelease :app:assembleFdroidRelease
```

The preparation removes unused store-only sources/declarations. The release is
unsigned without private signing variables. F-Droid's own signing route and
cross-channel update compatibility must be documented before publication.

## License and source

First-party code and supplied app artwork: MIT, copyright Luke Steuber.
The loop engine adapts Dillon (Dillo)'s MIT-licensed loop-construction family;
Mash ancestry includes Dillon, GRC/Steve Gibson and Johannes Baagoe.
See [all notices](THIRD_PARTY_NOTICES.md), [provenance](docs/FDROID_PROVENANCE.md)
and `LICENSES/`. Runtime components include Apache-2.0, BSD-3-Clause and
Boost-1.0 portions; this app's MIT license does not relicense them.

This export contains complete Android build inputs without private Git history,
Apple/TV/Wear build configurations, signing material or local machine settings.
`SOURCE_EXPORT.json` records the source revision, transformations and hashes.
Author: [Luke Steuber](https://lukesteuber.com/).
""")
metadata = destination / "fdroid/metadata/app.mandaza.android.yml"
text = re.sub(r"https://github\.com/lukeslp/mandaza(?=[./\s]|$)",
              "https://github.com/lukeslp/mandaza-android", metadata.read_text())
candidate_version = re.search(r"  - versionName: ([^\n]+)", text)
assert candidate_version, "Candidate version missing"
text = re.sub(r"    commit: .+", "    commit: fdroid-v" + candidate_version[1].strip(), text)
metadata.write_text(text)
files = {
    str(path.relative_to(destination)): hashlib.sha256(path.read_bytes()).hexdigest()
    for path in sorted(destination.rglob("*")) if path.is_file()
}
(destination / "SOURCE_EXPORT.json").write_text(json.dumps({
    "sourceRevision": revision, "purpose": "complete Android source export for review",
    "transforms": ["Android phone/core input allowlist", "Android-only README",
                   "Version-only project.yml", "Phone/core module list",
                   "Proposed public repository/tag in disabled draft metadata"],
    "files": files,
}, indent=2) + "\n")
print(json.dumps({"sourceRevision": revision, "output": str(destination), "files": len(files)}))
