#!/usr/bin/env bash
# Upload the signed .ipa to App Store Connect → TestFlight.
# Primary operations: select exactly one platform IPA and upload it with the
# centrally configured API key (or an explicit Apple ID fallback).
# I/O: Reads build/export* plus ~/.appstoreconnect/env.sh; submits one IPA.
#
#   scripts/upload-testflight.sh          # iOS Mandaza (build/export/*.ipa)
#   scripts/upload-testflight.sh --tvos   # tvOS MandazaTV (build/export-tvos/*.ipa)
#
# Reads App Store Connect API key selection from ~/.appstoreconnect/env.sh.
# See TESTFLIGHT.md for one-time key setup.
#
# Alternative (without API key): export ASC_APPLE_ID and APP_SPECIFIC_PASSWORD
# environment variables before running.

set -euo pipefail
cd "$(dirname "$0")/.."

ALTOOL_TYPE="ios"
IPA_DIR="build/export"

case "$#" in
    0) ;;
    1)
        if [ "$1" = "--tvos" ]; then
            ALTOOL_TYPE="appletvos"
            IPA_DIR="build/export-tvos"
        else
            echo "Usage: scripts/upload-testflight.sh [--tvos]" >&2
            exit 2
        fi
        ;;
    *)
        echo "Usage: scripts/upload-testflight.sh [--tvos]" >&2
        exit 2
        ;;
esac

shopt -s nullglob
IPAS=("${IPA_DIR}"/*.ipa)
if [ "${#IPAS[@]}" -eq 0 ]; then
    echo "✗ No .ipa found in ${IPA_DIR}." >&2
    if [ "${ALTOOL_TYPE}" = "appletvos" ]; then
        echo "    Run: scripts/archive-tvos.sh && scripts/export-ipa-tvos.sh" >&2
    else
        echo "    Run: scripts/archive.sh && scripts/export-ipa.sh" >&2
    fi
    exit 1
fi
if [ "${#IPAS[@]}" -ne 1 ]; then
    echo "✗ Expected one .ipa in ${IPA_DIR}, found ${#IPAS[@]}. Remove stale exports." >&2
    exit 1
fi
IPA="${IPAS[0]}"

echo "→ Uploading ${IPA} (--type ${ALTOOL_TYPE})"

# Prefer the active centralized API key; never guess from whichever .p8 sorts first.
ENV_FILE="${HOME}/.appstoreconnect/env.sh"
if [ -f "${ENV_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${ENV_FILE}"
fi
KEY_ID="${APP_STORE_CONNECT_API_KEY_KEY_ID:-}"
KEY_ISSUER="${APP_STORE_CONNECT_API_KEY_ISSUER_ID:-${ASC_API_ISSUER:-}}"
if [ -n "${KEY_ID}" ] || [ -n "${KEY_ISSUER}" ]; then
    if [ -z "${KEY_ID}" ] || [ -z "${KEY_ISSUER}" ]; then
        echo "✗ Central API key configuration is incomplete in ${ENV_FILE}." >&2
        exit 1
    fi

    xcrun altool --upload-app \
        --type "${ALTOOL_TYPE}" \
        --file "${IPA}" \
        --apiKey "${KEY_ID}" \
        --apiIssuer "${KEY_ISSUER}"
elif [ -n "${ASC_APPLE_ID:-}" ] && [ -n "${APP_SPECIFIC_PASSWORD:-}" ]; then
    xcrun altool --upload-app \
        --type "${ALTOOL_TYPE}" \
        --file "${IPA}" \
        --username "${ASC_APPLE_ID}" \
        --password "${APP_SPECIFIC_PASSWORD}"
else
    cat >&2 <<'EOF'
✗ No App Store Connect credentials found.
  Either:
    • Configure the active API key in ~/.appstoreconnect/env.sh
  Or:
    • Set ASC_APPLE_ID=<your-apple-id> and APP_SPECIFIC_PASSWORD=<app-specific-password>
  See TESTFLIGHT.md for the one-time setup.
EOF
    exit 1
fi

echo "✓ Upload submitted. Apple will email when processing completes."
echo "  Check status: https://appstoreconnect.apple.com/apps → TestFlight"
