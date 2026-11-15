#!/bin/bash
# Store screenshots of Mandaza on the iPhone Duo simulator, outer or inner screen.
#
#   scripts/capture-duo.sh <udid> <outer|inner> <outdir> [path/to/Mandaza.app]
#
# Needs a Debug build: the scenes come from the DEBUG-only environment hooks in
# MandazaCore/ScreenshotSupport.swift (MANDAZA_PALETTE, MANDAZA_MUSIC_DEMO,
# MANDAZA_CLOCK_FORM), passed with SIMCTL_CHILD_. A Release build ignores them
# and the script refuses its shots (the music scene would not enter Zen).
#
#   outer  folded Duo, `simctl io --display=1`, 1398x2034
#   inner  unfolded Duo (Device Hub), `--display=LCD-1`, 2007x2853 portrait or
#          2853x2007 landscape
#
# Shots: 01-mandalas.png (home grid, Aurora), 02-music-zen.png (Zen with the
# synthetic music signal), 03-clock-stacked.png (Zen, stacked clock, Ember).
# Each one is refused when it is the wrong size, black, or not steady for two
# frames, or when the scene did not change the picture. Kept shots are flattened
# to opaque sRGB, as App Store Connect wants. Build the app with:
#   xcodegen && xcodebuild -project Mandaza.xcodeproj -scheme Mandaza -configuration Debug \
#     -destination "id=<udid>" -derivedDataPath <dd> CODE_SIGNING_ALLOWED=NO build
#   # App: <dd>/Build/Products/Debug-iphonesimulator/Mandaza.app
#
# Env: MANDAZA_TIMEOUT seconds per scene (default 90).
set -uo pipefail

usage() { echo "usage: $0 <udid> <outer|inner> <outdir> [path/to/Mandaza.app]" >&2; exit 2; }
[ $# -ge 3 ] || usage
UDID=$1; SCREEN=$2; OUT=$3; APP=${4:-}
BUNDLE=com.lukesteuber.mandaza
TIMEOUT=${MANDAZA_TIMEOUT:-90}
case "$SCREEN" in
  outer) DISPLAY_ARG=1;     SIZES="1398x2034" ;;
  inner) DISPLAY_ARG=LCD-1; SIZES="2007x2853 2853x2007" ;;
  *) usage ;;
esac
command -v magick >/dev/null || { echo "needs ImageMagick 7 (magick)" >&2; exit 1; }
fail() { echo "REFUSED: $*" >&2; exit 1; }

xcrun simctl list devices | grep -q "($UDID) (Booted)" || fail "simulator $UDID is not booted"
if [ "$SCREEN" = inner ]; then
  if info=$(xcrun devicectl device info displays --device "$UDID" 2>/dev/null); then
    echo "$info" | awk '/LCD-1/{f=1} f&&/ active:/{print; exit}' | grep -q "active: true" \
      || fail "inner display LCD-1 is not active: unfold the Duo in Device Hub first"
  fi
fi
if [ -n "$APP" ]; then
  id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null)
  [ "$id" = "$BUNDLE" ] || fail "$APP is not $BUNDLE (got '$id')"
  xcrun simctl install "$UDID" "$APP" || fail "install failed"
fi

mkdir -p "$OUT"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mandaza-duo.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

shot() { xcrun simctl io "$UDID" screenshot --display="$DISPLAY_ARG" --mask=ignored "$1" >/dev/null 2>&1; }
stats() { magick "$1" -alpha off -format '%w %h %[fx:mean] %[fx:standard_deviation]' info: 2>/dev/null; }

launch() { # <palette> <music 0|1> <clock form or ''>
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
  env SIMCTL_CHILD_MANDAZA_PALETTE="$1" SIMCTL_CHILD_MANDAZA_MUSIC_DEMO="$2" \
      ${3:+SIMCTL_CHILD_MANDAZA_CLOCK_FORM="$3"} \
      xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null || fail "launch failed"
}

prev_shot=""
n=0
for scene in mandalas music clock; do
  n=$((n + 1))
  case "$scene" in
    mandalas) name=01-mandalas;      launch aurora 0 "" ;;
    music)    name=02-music-zen;     launch vaporwave 1 "" ;;
    clock)    name=03-clock-stacked; launch ember 1 stacked ;;
  esac
  prev=""; ok=""; t0=$SECONDS
  while [ $((SECONDS - t0)) -lt "$TIMEOUT" ]; do
    sleep 2
    cur="$WORK/$scene-$SECONDS.png"
    shot "$cur" || continue
    read -r w h mean sd <<<"$(stats "$cur")"
    # Zen scenes animate, so steady means "painted twice with similar mean".
    if awk -v s="$sd" 'BEGIN{exit !(s > 0.02)}' && [ -n "$prev" ]; then ok=$cur; break; fi
    prev=$cur
  done
  [ -n "$ok" ] || fail "$scene: no painted screen within ${TIMEOUT}s (last: ${w:-?}x${h:-?} mean ${mean:-?} sd ${sd:-?})"
  read -r w h mean sd <<<"$(stats "$ok")"
  echo " $SIZES " | grep -q " ${w}x${h} " || fail "$scene: ${w}x${h}, expected one of: $SIZES"
  awk -v m="$mean" 'BEGIN{exit !(m > 0.01)}' || fail "$scene: black screen (mean $mean)"
  if [ -n "$prev_shot" ] && [ "$(magick compare -metric AE -fuzz 2% "$prev_shot" "$ok" null: 2>&1 | cut -d' ' -f1)" = "0" ]; then
    fail "$scene: identical to the previous scene (the launch hooks did not apply: Release build?)"
  fi
  prev_shot=$ok
  magick "$ok" -background black -alpha remove -alpha off -define png:color-type=2 "$OUT/$name.png" || fail "flatten failed"
  ch=$(magick identify -format '%[channels]' "$OUT/$name.png")
  [ "${ch%% *}" = srgb ] || fail "$scene: expected opaque sRGB after flattening, got '$ch'"
  printf '%s  %sx%s  mean %.3f  sd %.3f  %s\n' "$OUT/$name.png" "$w" "$h" "$mean" "$sd" "$ch"
done
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
echo "ok: $n $SCREEN shots in $OUT"
