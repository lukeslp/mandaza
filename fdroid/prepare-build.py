#!/usr/bin/env python3
"""Prune store-only source references in a disposable F-Droid build sandbox.

The app's fdroid flavor already excludes those runtime dependencies. This step
also removes their source declarations for the official source scanner. Never
run it on a development checkout you intend to keep unchanged.
"""
from pathlib import Path
import argparse
import re
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--confirm-build-sandbox", action="store_true", required=True)
parser.parse_args()
root = Path(__file__).resolve().parents[1]
android = root / "android"
gradle = android / "app/build.gradle.kts"
settings = android / "settings.gradle.kts"
assert gradle.is_file() and settings.is_file(), "Not a Mandaza source tree"
assert not android.is_symlink(), "Refusing a linked Android source directory"

original = gradle.read_text()
cleaned, count = re.subn(
    r'^\s*add\("playImplementation", "com\.google\.android\.play:[^"\n]+"\)\s*$',
    "", original, flags=re.MULTILINE,
)
assert count in (0, 2), "Play dependency declarations changed; review the recipe"
assert "com.google.android.play:" not in cleaned, "Unreviewed Play dependency remains"
configuration = settings.read_text().replace(
    'include(":core", ":app", ":wear", ":tv")', 'include(":core", ":app")',
)
assert 'include(":core", ":app")' in configuration, "Module list changed; review the recipe"

gradle.write_text(cleaned)
settings.write_text(configuration)
for relative in (
    "app/src/play", "app/src/direct", "app/src/amazon",
    "app/src/testPlay", "app/src/testDirect", "app/src/testAmazon", "wear", "tv",
):
    path = android / relative
    if path.exists():
        assert not path.is_symlink(), "Refusing linked store-only source"
        shutil.rmtree(path)
print("Prepared phone/core source for F-Droid; store-only sources removed.")
