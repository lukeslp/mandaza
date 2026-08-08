#!/bin/sh
# Stage a signed MandazaTV (:tv) release APK.
# Expects MANDAZA_ANDROID_STORE_* env vars (or android-release with-signing).
set -eu

android_dir=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cd "$android_dir"

for variable in MANDAZA_ANDROID_STORE_FILE MANDAZA_ANDROID_STORE_PASSWORD MANDAZA_ANDROID_KEY_ALIAS MANDAZA_ANDROID_KEY_PASSWORD; do
  value=$(printenv "$variable" || true)
  if [ -z "$value" ]; then
    echo "Missing required signing environment variable: $variable" >&2
    echo "Use: android-release with-signing --profile mandaza -- $0" >&2
    exit 1
  fi
done

export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21)}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

./gradlew :core:testDebugUnitTest :tv:testDebugUnitTest :tv:assembleRelease

version=$(./gradlew --quiet :tv:printVersion | awk 'NF { value=$0 } END { print value }')
apk="$android_dir/tv/build/outputs/apk/release/tv-release.apk"
test -f "$apk"

build_tools=$(ls -d "$ANDROID_HOME"/build-tools/*/ 2>/dev/null | sort -V | tail -1)
"$build_tools/apksigner" verify --verbose "$apk"

stage_dir="$android_dir/tv/dist/release"
mkdir -p "$stage_dir"
out_apk="$stage_dir/MandazaTV-$version-release.apk"
cp "$apk" "$out_apk"
(
  cd "$stage_dir"
  shasum -a 256 "MandazaTV-$version-release.apk" > SHA256SUMS.txt
  {
    echo "MandazaTV $version"
    echo "applicationId app.mandaza.tv"
    echo "versionCode 20300 (check aapt if rebuilt)"
    echo "built $(date -u +%Y-%m-%dT%H:%MZ)"
    echo "track Fire TV Amazon Appstore"
  } > PROVENANCE.txt
)

echo "Staged signed MandazaTV release: $out_apk"
cat "$stage_dir/SHA256SUMS.txt"
