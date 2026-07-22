#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
android_dir="$repo_root/android"
distribution=${MANDAZA_DISTRIBUTION:-direct}

case "$distribution" in
  direct) variant=Direct ;;
  play) variant=Play ;;
  *) echo "MANDAZA_DISTRIBUTION must be direct or play" >&2; exit 1 ;;
esac

for variable in MANDAZA_ANDROID_STORE_FILE MANDAZA_ANDROID_STORE_PASSWORD MANDAZA_ANDROID_KEY_ALIAS MANDAZA_ANDROID_KEY_PASSWORD; do
  value=$(printenv "$variable" || true)
  if [ -z "$value" ]; then
    echo "Missing required signing environment variable: $variable" >&2
    exit 1
  fi
done

version=$(cd "$android_dir" && ./gradlew --quiet :app:printVersion | awk 'NF { value=$0 } END { print value }')
case "$version" in
  *[!0-9A-Za-z._-]*|"") echo "Invalid Android version: $version" >&2; exit 1 ;;
esac

(cd "$android_dir" && ./gradlew clean :core:testDebugUnitTest \
  ":app:test${variant}DebugUnitTest" ":app:lint${variant}Release" \
  ":app:assemble${variant}Release" ":app:bundle${variant}Release")

lower_distribution=$(printf '%s' "$distribution" | tr '[:upper:]' '[:lower:]')
apk="$android_dir/app/build/outputs/apk/$lower_distribution/release/app-$lower_distribution-release.apk"
aab="$android_dir/app/build/outputs/bundle/${lower_distribution}Release/app-${lower_distribution}-release.aab"
test -f "$apk"
test -f "$aab"
build_tools="${ANDROID_HOME:-$HOME/Library/Android/sdk}/build-tools/36.0.0"
"$build_tools/apksigner" verify --verbose "$apk"
jarsigner -verify "$aab"

stage_dir="$repo_root/dist/android/$distribution/v$version"
mkdir -p "$stage_dir"
cp "$apk" "$stage_dir/Mandaza-$version-$distribution.apk"
cp "$aab" "$stage_dir/Mandaza-$version-$distribution.aab"
(cd "$stage_dir" && shasum -a 256 "Mandaza-$version-$distribution.apk" "Mandaza-$version-$distribution.aab" > SHA256SUMS.txt)
echo "Staged signed Android $distribution artifact in $stage_dir"
