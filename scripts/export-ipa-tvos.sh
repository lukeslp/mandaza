#!/usr/bin/env bash
# Export a signed tvOS .ipa from the MandazaTV xcarchive.
#
#   scripts/export-ipa-tvos.sh
#
# Requires: scripts/archive-tvos.sh to have run first.
# Output: build/export-tvos/MandazaTV.ipa

set -euo pipefail
cd "$(dirname "$0")/.."

# Xcode's packaging pipeline invokes Apple's openrsync, which starts a second
# `rsync` through PATH. Prefer system tools so a Homebrew rsync cannot become
# the incompatible peer and fail the IPA copy step.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

ARCHIVE="build/MandazaTV.xcarchive"
EXPORT_DIR="build/export-tvos"
OPTIONS="${EXPORT_OPTIONS:-scripts/ExportOptions.plist}"

if [ ! -f "${OPTIONS}" ]; then
    echo "✗ No export options at ${OPTIONS}." >&2
    echo "  Copy scripts/ExportOptions.example.plist to scripts/ExportOptions.plist" >&2
    echo "  and set your Apple Developer team ID, or point EXPORT_OPTIONS at your own file." >&2
    exit 1
fi

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
        echo "✗ tvOS export failed. Check signing: team ID, tvOS App ID, and distribution profile." >&2
        exit 1
    }

shopt -s nullglob
IPAS=("${EXPORT_DIR}"/*.ipa)
if [ "${#IPAS[@]}" -ne 1 ]; then
    echo "✗ Expected exactly one .ipa in ${EXPORT_DIR}, found ${#IPAS[@]}." >&2
    exit 1
fi
IPA="${IPAS[0]}"
echo "✓ tvOS IPA at ${IPA}"
echo "  Next: scripts/upload-testflight.sh --tvos"
