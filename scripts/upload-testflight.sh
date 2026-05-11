#!/usr/bin/env bash
# Upload the signed .ipa to App Store Connect → TestFlight.
#
#   scripts/upload-testflight.sh
#
# Reads App Store Connect API key from ~/.appstoreconnect/private_keys/.
# See TESTFLIGHT.md for one-time key setup.
#
# Alternative (without API key): export ASC_APPLE_ID and APP_SPECIFIC_PASSWORD
# environment variables before running.

set -euo pipefail
cd "$(dirname "$0")/.."

IPA="$(find build/export -name '*.ipa' 2>/dev/null | head -1 || true)"
if [ -z "${IPA}" ]; then
    echo "✗ No .ipa found in build/export. Run scripts/export-ipa.sh first." >&2
    exit 1
fi

echo "→ Uploading ${IPA}"

# Prefer API-key auth (cleaner, no 2FA prompts, scriptable).
KEY_DIR="${HOME}/.appstoreconnect/private_keys"
if [ -d "${KEY_DIR}" ] && [ -n "$(ls "${KEY_DIR}" 2>/dev/null)" ]; then
    KEY_FILE="$(ls "${KEY_DIR}"/AuthKey_*.p8 2>/dev/null | head -1)"
    if [ -z "${KEY_FILE}" ]; then
        echo "✗ No AuthKey_*.p8 file in ${KEY_DIR}" >&2
        exit 1
    fi
    KEY_ID="$(basename "${KEY_FILE}" .p8 | sed 's/AuthKey_//')"

    if [ -z "${ASC_API_ISSUER:-}" ]; then
        echo "✗ Set ASC_API_ISSUER (your App Store Connect API issuer UUID)." >&2
        echo "    Find it at appstoreconnect.apple.com → Users and Access → Integrations → App Store Connect API" >&2
        exit 1
    fi

    xcrun altool --upload-app \
        --type ios \
        --file "${IPA}" \
        --apiKey "${KEY_ID}" \
        --apiIssuer "${ASC_API_ISSUER}"
elif [ -n "${ASC_APPLE_ID:-}" ] && [ -n "${APP_SPECIFIC_PASSWORD:-}" ]; then
    xcrun altool --upload-app \
        --type ios \
        --file "${IPA}" \
        --username "${ASC_APPLE_ID}" \
        --password "${APP_SPECIFIC_PASSWORD}"
else
    cat >&2 <<'EOF'
✗ No App Store Connect credentials found.
  Either:
    • Place AuthKey_<KEYID>.p8 in ~/.appstoreconnect/private_keys/
      AND set ASC_API_ISSUER=<your-issuer-uuid>
  Or:
    • Set ASC_APPLE_ID=<your-apple-id> and APP_SPECIFIC_PASSWORD=<app-specific-password>
  See TESTFLIGHT.md for the one-time setup.
EOF
    exit 1
fi

echo "✓ Upload submitted. Apple will email when processing completes."
echo "  Check status: https://appstoreconnect.apple.com/apps → TestFlight"
