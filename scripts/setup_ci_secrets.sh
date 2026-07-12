#!/usr/bin/env bash
set -euo pipefail

# One-time setup: pushes the secrets needed by release-prod.yml and
# shorebird-patch.yml to the GitHub repository via `gh secret set`.
#
# Run from the Trovara repo root:  ./scripts/setup_ci_secrets.sh
#
# Prerequisites:
#   - gh CLI authenticated with access to this repo
#   - Decrypted prod credentials at ../credentials/android/trovara/prod/
#   - configs/trovara_prod.json and lib/firebase_options/prod.dart present
#   - PLAY_SERVICE_ACCOUNT_JSON_FILE env var pointing at the Play service
#     account key file (create it in Google Cloud Console → IAM → Service
#     Accounts, grant it "Release manager" in Play Console → Users & access)
#   - SHOREBIRD_TOKEN_VALUE env var with a CI token from the Shorebird console
#     (console.shorebird.dev → Account → CI tokens)

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
CRED_DIR="../credentials/android/trovara/prod"

fail() { echo "❌ $1" >&2; exit 1; }

[[ -f "${CRED_DIR}/upload.jks" ]] || fail "Missing ${CRED_DIR}/upload.jks (decrypt credentials first)"
[[ -f "${CRED_DIR}/keystore.properties" ]] || fail "Missing ${CRED_DIR}/keystore.properties"
[[ -f "configs/trovara_prod.json" ]] || fail "Missing configs/trovara_prod.json"
[[ -f "lib/firebase_options/prod.dart" ]] || fail "Missing lib/firebase_options/prod.dart"

echo "🔐 Setting secrets on ${REPO}..."

base64 -i "${CRED_DIR}/upload.jks" | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PROPERTIES < "${CRED_DIR}/keystore.properties"
gh secret set TROVARA_PROD_CONFIG_JSON < configs/trovara_prod.json
gh secret set FIREBASE_OPTIONS_PROD_DART < lib/firebase_options/prod.dart
gh secret set GOOGLE_SERVICES_PROD_JSON < android/app/src/prod/google-services.json

if [[ -n "${PLAY_SERVICE_ACCOUNT_JSON_FILE:-}" ]]; then
  [[ -f "${PLAY_SERVICE_ACCOUNT_JSON_FILE}" ]] || fail "PLAY_SERVICE_ACCOUNT_JSON_FILE not found: ${PLAY_SERVICE_ACCOUNT_JSON_FILE}"
  gh secret set PLAY_SERVICE_ACCOUNT_JSON < "${PLAY_SERVICE_ACCOUNT_JSON_FILE}"
else
  echo "⚠️  Skipped PLAY_SERVICE_ACCOUNT_JSON (set PLAY_SERVICE_ACCOUNT_JSON_FILE=/path/to/key.json and re-run)"
fi

if [[ -n "${SHOREBIRD_TOKEN_VALUE:-}" ]]; then
  printf '%s' "${SHOREBIRD_TOKEN_VALUE}" | gh secret set SHOREBIRD_TOKEN
else
  echo "⚠️  Skipped SHOREBIRD_TOKEN (set SHOREBIRD_TOKEN_VALUE=... and re-run)"
fi

echo "✅ Done. Current secrets:"
gh secret list
