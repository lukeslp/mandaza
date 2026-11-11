#!/usr/bin/env python3
"""Check the actual F-Droid APK and its resolved runtime/class reports."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
root = Path(__file__).resolve().parents[1]
parser.add_argument("apk", type=Path)
parser.add_argument("--metadata", type=Path, default=root / "fdroid/metadata/app.mandaza.android.yml")
parser.add_argument("--dependencies", type=Path, required=True)
parser.add_argument("--classes", type=Path, required=True)
parser.add_argument("--build-tools", type=Path, required=True)
args = parser.parse_args()
badging = subprocess.run(
    [str(args.build_tools / "aapt2"), "dump", "badging", str(args.apk)],
    capture_output=True, text=True, check=True,
).stdout
package = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging)
assert package and package[1] == "app.mandaza.android", "Unexpected release package"
metadata = args.metadata.read_text()
expected = re.search(r"  - versionName: ([^\n]+)\n    versionCode: (\d+)", metadata)
assert expected, "Candidate version missing from recipe"
assert package[2] == expected[2] and package[3] == expected[1].strip().strip("\"'"), "APK version differs from candidate recipe"
assert "application-debuggable" not in badging, "Release is debuggable"
permissions = re.findall(r"uses-permission(?:-sdk-\d+)?: name='([^']+)'", badging)
allowed = {
    "android.permission.RECORD_AUDIO", "android.permission.WRITE_EXTERNAL_STORAGE",
    "android.permission.READ_EXTERNAL_STORAGE",
    "app.mandaza.android.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
}
assert set(permissions) <= allowed, "Unreviewed permission in F-Droid APK"
for permission in ("READ_EXTERNAL_STORAGE", "WRITE_EXTERNAL_STORAGE"):
    if "android.permission." + permission in permissions:
        assert f"name='android.permission.{permission}' maxSdkVersion='28'" in badging, "Legacy storage access is not SDK-bounded"
deps = args.dependencies.read_text()
classes = args.classes.read_text()
assert "fdroidReleaseRuntimeClasspath" in deps and "FAILED" not in deps
assert "com.lukesteuber.mandaza" in classes, "Missing or wrong DEX package report"
forbidden = (
    "com.google.android.play", "com.google.android.gms",
    "com.google.mlkit", "com.google.firebase",
)
for name in forbidden:
    assert name not in deps and name not in classes, "Prohibited SDK in resolved artifact: " + name
signing = subprocess.run(
    [str(args.build_tools / "apksigner"), "verify", str(args.apk)],
    capture_output=True, text=True,
)
assert signing.returncode != 0, "Expected the unsigned F-Droid build, not a developer-signed APK"
assert signing.returncode == 1 and "ERROR: Missing META-INF/MANIFEST.MF" in signing.stderr, "Signing verifier did not establish an unsigned APK: " + signing.stderr
minimum = re.search(r"(?:minSdkVersion|sdkVersion):'(\d+)'", badging)
target = re.search(r"targetSdkVersion:'(\d+)'", badging)
assert minimum and target
gradle = (root / "android/app/build.gradle.kts").read_text()
expected_min = re.search(r"\bminSdk\s*=\s*(\d+)", gradle)
expected_target = re.search(r"\btargetSdk\s*=\s*(\d+)", gradle)
assert expected_min and expected_target
assert minimum[1] == expected_min[1] and target[1] == expected_target[1], "APK SDK values differ from declared source"
with zipfile.ZipFile(args.apk) as archive:
    native = sorted(name for name in archive.namelist() if name.endswith(".so"))
    native_audit = json.loads((root / "docs/FDROID_NATIVE.json").read_text())
    reviewed_native = {entry["apkEntry"]: entry["sha256"] for entry in native_audit["libraries"]}
    assert native == sorted(reviewed_native), "Native library inventory changed; review provenance"
    for name in native:
        assert hashlib.sha256(archive.read(name)).hexdigest() == reviewed_native[name], "Native library differs from reviewed Maven artifact: " + name
    notices = {
        "assets/licenses/Mandaza-MIT.txt", "assets/licenses/Johannes-Baagoe-MIT.txt",
        "assets/licenses/Apache-2.0.txt", "assets/licenses/THIRD_PARTY_NOTICES.md",
        "assets/licenses/kotlinx-coroutines-NOTICE.txt",
        "assets/licenses/kotlinx-serialization-NOTICE.txt",
        "assets/licenses/Kotlin-ThreeTenBP-BSD-3-Clause.txt",
        "assets/licenses/Kotlin-Boost-1.0.txt",
        "assets/licenses/Dillon-Controlled-Loops-MIT.txt",
        "assets/licenses/Dillon-Loops-MIT.txt",
        "assets/licenses/GRC-Public-Domain.txt",
    }
    assert notices <= set(archive.namelist()), "Required license notices missing from APK"
    for name in notices:
        filename = Path(name).name
        source = root / ("LICENSE" if filename == "Mandaza-MIT.txt" else
                         "THIRD_PARTY_NOTICES.md" if filename == "THIRD_PARTY_NOTICES.md" else
                         "LICENSES/" + filename)
        assert archive.read(name) == source.read_bytes(), "Packaged notice differs from reviewed source: " + name
print(json.dumps({
    "package": package[1], "versionCode": int(package[2]), "versionName": package[3],
    "minSdk": int(minimum[1]), "targetSdk": int(target[1]),
    "permissions": permissions, "nativeLibraries": native,
    "unsigned": True, "excludedSdkClasses": list(forbidden),
    "sha256": hashlib.sha256(args.apk.read_bytes()).hexdigest(),
}, indent=2))
