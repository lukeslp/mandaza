#!/usr/bin/env bash
# Archive Mandaza for App Store / TestFlight (tvOS destination).
#
#   scripts/archive-tvos.sh
#
# Output: build/Mandaza-tvOS.xcarchive
# Then run:
#   scripts/export-ipa-tvos.sh     # produces build/export-tvos/*.ipa
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
SCHEME="Mandaza"
CONFIG="Release"
ARCHIVE="build/Mandaza-tvOS.xcarchive"

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
        echo "    • App ID 'com.lukesteuber.mandaza' is not enabled for tvOS"
        echo "    • A stale tvOS profile expects an App Group entitlement"
        echo "    • No matching App Store distribution profile installed"
        echo "  See PROVISIONING.md and TESTFLIGHT.md." >&2
        exit 1
    }

echo "✓ tvOS archive at ${ARCHIVE}"
echo "  Next: scripts/export-ipa-tvos.sh"
