#!/usr/bin/env bash
# Archive Mandaza for App Store / TestFlight distribution.
#
#   scripts/archive.sh
#
# Output: build/Mandaza.xcarchive
# Then run:
#   scripts/export-ipa.sh         # produces build/Mandaza.ipa
#   scripts/upload-testflight.sh  # uploads to App Store Connect
#
# tvOS (separate bundle): scripts/archive-tvos.sh → export-ipa-tvos.sh → upload-testflight.sh --tvos
#
# Requires: xcodegen, Xcode 26.4+, Apple Developer membership.
#
# Environment:
#   SKIP_TESTS=1  — skip the pre-archive `xcodebuild test` gate (local fast path).

set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="Mandaza.xcodeproj"
SCHEME="Mandaza"
CONFIG="Release"
ARCHIVE="build/Mandaza.xcarchive"

# Regenerate the project so any project.yml changes land in the archive.
xcodegen --quiet

if [[ "${SKIP_TESTS:-}" != "1" ]]; then
    echo "→ Running unit tests (set SKIP_TESTS=1 to skip)"
    xcodebuild test \
        -project "${PROJECT}" \
        -scheme "${SCHEME}" \
        -destination 'platform=iOS Simulator,name=iPhone 17' \
        -configuration Debug \
        2>&1 | (which xcbeautify >/dev/null 2>&1 && xcbeautify --quiet || tail -50) || {
            echo "✗ Tests failed. Fix failures before archiving, or use SKIP_TESTS=1 for a local-only archive." >&2
            exit 1
        }
    echo "✓ Tests passed"
else
    echo "→ Skipping tests (SKIP_TESTS=1)"
fi

# Auto-increment CFBundleVersion based on current count of git commits.
# Marketing version (CFBundleShortVersionString) is held steady in project.yml.
BUILD_NUMBER="$(git rev-list --count HEAD)"
echo "→ Build number: ${BUILD_NUMBER}"

mkdir -p build
rm -rf "${ARCHIVE}"

xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    -destination "generic/platform=iOS" \
    -archivePath "${ARCHIVE}" \
    CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
    archive \
    2>&1 | (which xcbeautify >/dev/null 2>&1 && xcbeautify --quiet || tail -40) || {
        echo "✗ Archive failed. Common causes:"
        echo "    • App Group 'group.com.lukesteuber.mandaza' not registered at developer.apple.com → Identifiers → App Groups"
        echo "    • Bundle ID 'com.lukesteuber.mandaza' not registered as an App ID with App Groups capability enabled"
        echo "    • No matching distribution provisioning profile installed"
        echo "    • Automatic signing disabled and no profile selected"
        echo "  See TESTFLIGHT.md for the user-side setup checklist."
        exit 1
    }

echo "✓ Archive at ${ARCHIVE}"
echo "  Next: scripts/export-ipa.sh"
