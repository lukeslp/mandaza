#!/usr/bin/env bash
# Archive MandazaTV for App Store / TestFlight (tvOS).
#
#   scripts/archive-tvos.sh
#
# Output: build/MandazaTV.xcarchive
# Then run:
#   scripts/export-ipa-tvos.sh     # produces build/export-tvos/MandazaTV.ipa
#   scripts/upload-testflight.sh --tvos
#
# Requires: xcodegen, Xcode with tvOS SDK, Apple Developer membership.
#
# Environment:
#   SKIP_TESTS=1  — skip the pre-archive Debug `xcodebuild build` smoke on tvOS Simulator.

set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE_LOCK="${TMPDIR:-/tmp}/mandaza-archive-${UID}.lock"
if ! mkdir "${ARCHIVE_LOCK}" 2>/dev/null; then
    echo "✗ Another Mandaza archive is already running (${ARCHIVE_LOCK})." >&2
    exit 1
fi
trap 'rmdir "${ARCHIVE_LOCK}" 2>/dev/null || true' EXIT

PROJECT="Mandaza.xcodeproj"
SCHEME="MandazaTV"
CONFIG="Release"
ARCHIVE="build/MandazaTV.xcarchive"

BUILD_NUMBER="$(scripts/build-number.sh --next)"
echo "→ tvOS build number: ${BUILD_NUMBER}"
xcodegen --quiet

if [[ "${SKIP_TESTS:-}" != "1" ]]; then
    echo "→ tvOS Debug build smoke (set SKIP_TESTS=1 to skip)"
    xcodebuild build \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination 'generic/platform=tvOS Simulator' \
        -configuration Debug \
        2>&1 | (which xcbeautify >/dev/null 2>&1 && xcbeautify --quiet || tail -50) || {
            echo "✗ tvOS build smoke failed." >&2
            exit 1
        }
    echo "✓ tvOS build smoke passed"
else
    echo "→ Skipping tvOS build smoke (SKIP_TESTS=1)"
fi

mkdir -p build
rm -rf "${ARCHIVE}"

xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    -destination "generic/platform=tvOS" \
    -archivePath "${ARCHIVE}" \
    CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
    archive \
    2>&1 | (which xcbeautify >/dev/null 2>&1 && xcbeautify --quiet || tail -40) || {
        echo "✗ tvOS archive failed. Common causes:" >&2
        echo "    • App ID 'com.lukesteuber.mandaza.tv' is missing or App Groups is not enabled"
        echo "    • App Group 'group.com.lukesteuber.mandaza' is not enabled on the tvOS App ID"
        echo "    • No matching App Store distribution profile is installed"
        exit 1
    }

echo "✓ tvOS archive at ${ARCHIVE}"
echo "  Next: scripts/export-ipa-tvos.sh"
