#!/usr/bin/env bash
# Export a signed .ipa from the xcarchive for App Store Connect distribution.
#
#   scripts/export-ipa.sh
#
# Requires: scripts/archive.sh to have run first.
# Output: build/export/Mandala.ipa

set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE="build/Mandala.xcarchive"
EXPORT_DIR="build/export"
OPTIONS="scripts/ExportOptions.plist"

if [ ! -d "${ARCHIVE}" ]; then
    echo "✗ No archive at ${ARCHIVE}. Run scripts/archive.sh first." >&2
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
        echo "✗ Export failed. See TESTFLIGHT.md for signing setup." >&2
        exit 1
    }

IPA="$(find "${EXPORT_DIR}" -name '*.ipa' | head -1)"
echo "✓ IPA at ${IPA}"
echo "  Next: scripts/upload-testflight.sh"
