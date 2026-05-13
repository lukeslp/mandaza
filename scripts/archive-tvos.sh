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

PROJECT="Mandaza.xcodeproj"
SCHEME="MandazaTV"
CONFIG="Release"
ARCHIVE="build/MandazaTV.xcarchive"

xcodegen --quiet

if [[ "${SKIP_TESTS:-}" != "1" ]]; then
    echo "→ tvOS Debug build smoke (set SKIP_TESTS=1 to skip)"
    xcodebuild build \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination 'platform=tvOS Simulator,name=Apple TV' \
        -configuration Debug \
        2>&1 | (which xcbeautify >/dev/null 2>&1 && xcbeautify --quiet || tail -50) || {
            echo "✗ tvOS build smoke failed." >&2
            exit 1
        }
    echo "✓ tvOS build smoke passed"
else
    echo "→ Skipping tvOS build smoke (SKIP_TESTS=1)"
fi

BUILD_NUMBER="$(git rev-list --count HEAD)"
echo "→ tvOS build number: ${BUILD_NUMBER}"

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
        echo "    • App ID 'com.lukesteuber.mandaza.tv' missing or App Groups not enabled"
        echo "    • App Group 'group.com.lukesteuber.mandaza' not on the tvOS App ID"
        echo "    • No matching App Store distribution profile (create tvOS app in App Store Connect first)"
        echo "  See PROVISIONING.md and TESTFLIGHT.md (tvOS section)." >&2
        exit 1
    }

echo "✓ tvOS archive at ${ARCHIVE}"
echo "  Next: scripts/export-ipa-tvos.sh"
