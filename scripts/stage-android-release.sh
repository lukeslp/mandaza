#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
android_dir="$repo_root/android"
distribution=${MANDAZA_DISTRIBUTION:-direct}

# This private preparation branch changes shared app code, while the direct
# and Play flavors still carry already-issued, lower version codes.
if [ "$distribution" != amazon ]; then
  echo "This preparation branch stages only Amazon 1.3.7 (10313). Review and raise other flavor versions before staging them." >&2
  exit 1
fi

case "$distribution" in
  direct) variant=Direct ;;
  play) variant=Play ;;
  amazon) variant=Amazon ;;
  *) echo "MANDAZA_DISTRIBUTION must be direct, play, or amazon" >&2; exit 1 ;;
esac

for variable in MANDAZA_ANDROID_STORE_FILE MANDAZA_ANDROID_STORE_PASSWORD MANDAZA_ANDROID_KEY_ALIAS MANDAZA_ANDROID_KEY_PASSWORD; do
  value=$(printenv "$variable" || true)
  if [ -z "$value" ]; then
    echo "Missing required signing environment variable: $variable" >&2
    exit 1
  fi
done

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

badging=$($build_tools/aapt2 dump badging "$apk")
case "$badging" in
  *"package: name='app.mandaza.android'"*) ;;
  *) echo "Unexpected Android package identity" >&2; exit 1 ;;
esac

# Name the staged files from the built flavor's own versionName; flavors may override the default.
version=$(printf '%s\n' "$badging" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p" | head -1)
case "$version" in
  *[!0-9A-Za-z._-]*|"") echo "Invalid Android version: $version" >&2; exit 1 ;;
esac

if [ "$distribution" = amazon ]; then
  case "$badging" in
    *"versionCode='10313'"*) ;;
    *) echo "Amazon artifact must use version code 10313" >&2; exit 1 ;;
  esac
  if printf '%s\n' "$badging" | grep -q "uses-permission: name='android.permission.INTERNET'"; then
    echo "Amazon artifact unexpectedly requests network access" >&2
    exit 1
  fi
  if (cd "$android_dir" && ./gradlew --quiet :app:dependencies --configuration amazonReleaseRuntimeClasspath) \
      | grep -q 'com.google.android.play:'; then
    echo "Amazon artifact unexpectedly includes Google Play libraries" >&2
    exit 1
  fi
fi

stage_dir="$repo_root/dist/android/$distribution/v$version"
mkdir -p "$stage_dir"
cp "$apk" "$stage_dir/Mandaza-$version-$distribution.apk"
cp "$aab" "$stage_dir/Mandaza-$version-$distribution.aab"
(cd "$stage_dir" && shasum -a 256 "Mandaza-$version-$distribution.apk" "Mandaza-$version-$distribution.aab" > SHA256SUMS.txt)
echo "Staged signed Android $distribution artifact in $stage_dir"
