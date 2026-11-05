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
parser.add_argument("apk", type=Path)
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
minimum = re.search(r"(?:minSdkVersion|sdkVersion):'(\d+)'", badging)
target = re.search(r"targetSdkVersion:'(\d+)'", badging)
assert minimum and target
with zipfile.ZipFile(args.apk) as archive:
    native = sorted(name for name in archive.namelist() if name.endswith(".so"))
    notices = {
        "assets/licenses/Mandaza-MIT.txt", "assets/licenses/Johannes-Baagoe-MIT.txt",
        "assets/licenses/Apache-2.0.txt", "assets/licenses/THIRD_PARTY_NOTICES.md",
    }
    assert notices <= set(archive.namelist()), "Required license notices missing from APK"
print(json.dumps({
    "package": package[1], "versionCode": int(package[2]), "versionName": package[3],
    "minSdk": int(minimum[1]), "targetSdk": int(target[1]),
    "permissions": permissions, "nativeLibraries": native,
    "unsigned": True, "excludedSdkClasses": list(forbidden),
    "sha256": hashlib.sha256(args.apk.read_bytes()).hexdigest(),
}, indent=2))
