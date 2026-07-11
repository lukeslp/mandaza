#!/usr/bin/env bash
# Export a signed tvOS .ipa from the Mandaza tvOS xcarchive.
#
#   scripts/export-ipa-tvos.sh
#
# Requires: scripts/archive-tvos.sh to have run first.
# Output: build/export-tvos/*.ipa

set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE="build/Mandaza-tvOS.xcarchive"
EXPORT_DIR="build/export-tvos"
OPTIONS="scripts/ExportOptions.plist"

if [ ! -d "${ARCHIVE}" ]; then
    echo "✗ No archive at ${ARCHIVE}. Run scripts/archive-tvos.sh first." >&2
    exit 1
fi

rm -rf "${EXPORT_DIR}"
mkdir -p "${EXPORT_DIR}"

xcodebuild \
    -exportArchive \
    -archivePath "${ARCHIVE}" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist "${OPTIONS}" \
    2>&1 | (which xcbeautify >/dev/null 2>&1 && xcbeautify --quiet || tail -40) || {
        echo "✗ tvOS export failed. See TESTFLIGHT.md (tvOS)." >&2
        exit 1
    }

IPA="$(find "${EXPORT_DIR}" -name '*.ipa' | head -1)"
echo "✓ tvOS IPA at ${IPA}"
echo "  Next: scripts/upload-testflight.sh --tvos"
