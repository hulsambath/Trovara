#!/usr/bin/env bash
set -euo pipefail

# Decrypt Android credentials for local development using local credentials project.
# The build.gradle.kts now reads directly from the credentials project.
# Usage:
#   scripts/keystore.sh --env dev [--age-key-file ~/.config/sops/age/keys.txt]

ENVIRONMENT="dev"
PROJECT="notemyminds"
AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
CREDENTIALS_DIR="../credentials"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENVIRONMENT="$2"; shift 2 ;;
    --project)
      PROJECT="$2"; shift 2 ;;
    --age-key-file)
      AGE_KEY_FILE="$2"; shift 2 ;;
    *) echo "❌ Unknown arg: $1"; exit 1 ;;
  esac
done

# For now, skip SOPS setup and work with plaintext credentials
# TODO: Set up SOPS encryption when ready

# Check if credentials directory exists
if [[ ! -d "${CREDENTIALS_DIR}" ]]; then
  echo "❌ Credentials directory not found: ${CREDENTIALS_DIR}" >&2
  echo "💡 Expected at: $(pwd)/${CREDENTIALS_DIR}" >&2
  exit 1
fi

# For now, work with plaintext credentials (will be encrypted later)
echo "📋 Working with plaintext credentials (SOPS encryption pending)..."

pushd "${CREDENTIALS_DIR}" >/dev/null

case "${ENVIRONMENT}" in
  dev)
    if [[ ! -f "android/${PROJECT}/dev/upload.jks" ]]; then
      echo "❌ Keystore not found: android/${PROJECT}/dev/upload.jks" >&2
      echo "💡 Generate keystore with: ./scripts/generate-keystore.sh --project ${PROJECT} --env dev" >&2
      exit 1
    fi
    echo "✅ Dev credentials found and ready to use"
    # Credentials are already in place, no decryption needed
    ;;
  prod)
    if [[ ! -f "android/${PROJECT}/prod/upload.jks" ]]; then
      echo "❌ Keystore not found: android/${PROJECT}/prod/upload.jks" >&2
      echo "💡 Generate keystore with: ./scripts/generate-keystore.sh --project ${PROJECT} --env prod" >&2
      exit 1
    fi
    echo "✅ Prod credentials found and ready to use"
    # Credentials are already in place, no decryption needed
    ;;
  *) echo "❌ Unknown env: ${ENVIRONMENT}"; exit 1 ;;
esac

popd >/dev/null

echo "✅ Credentials ready in $CREDENTIALS_DIR/android/${PROJECT}/$ENVIRONMENT/"
echo "🔧 Build.gradle.kts will now read from the credentials directory"
echo "🚀 You can now build with: flutter build apk --flavor $ENVIRONMENT"
