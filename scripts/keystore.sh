#!/usr/bin/env bash
set -euo pipefail

# Decrypt Android credentials for local development using local credentials project.
# The build.gradle.kts now reads directly from the credentials project.
# Usage:
#   scripts/keystore.sh --env dev [--age-key-file ~/.config/sops/age/keys.txt]

ENVIRONMENT="dev"
PROJECT="trovara"
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

# Check if credentials directory exists
if [[ ! -d "${CREDENTIALS_DIR}" ]]; then
  echo "❌ Credentials directory not found: ${CREDENTIALS_DIR}" >&2
  echo "💡 Expected at: $(pwd)/${CREDENTIALS_DIR}" >&2
  exit 1
fi

# Helper: decrypt a SOPS-encrypted file if the plaintext doesn't exist
decrypt_if_needed() {
  local cred_dir="$1" file="$2"
  if [[ -f "${cred_dir}/${file}" ]]; then
    echo "✅ ${file} already decrypted."
    return 0
  fi
  if [[ ! -f "${cred_dir}/${file}.enc" ]]; then
    echo "❌ Neither ${file} nor ${file}.enc found in ${cred_dir}" >&2
    return 1
  fi

  echo "🔐 Decrypting ${file}.enc with SOPS..."

  # Locate age private key
  local age_key="${AGE_KEY_FILE}"
  local cred_age_key="${CREDENTIALS_DIR}/scripts/age/trovara-age-key.txt"
  if [[ ! -f "${age_key}" ]]; then
    if [[ -f "${cred_age_key}" ]]; then
      mkdir -p "$(dirname "${age_key}")"
      cp "${cred_age_key}" "${age_key}"
      echo "📋 Installed age key to ${age_key}"
    else
      echo "❌ Age private key not found at ${age_key} or ${cred_age_key}" >&2
      return 1
    fi
  fi

  export SOPS_AGE_KEY_FILE="${age_key}"
  # Use appropriate SOPS options based on file type
  local sops_opts=""
  if [[ "${file}" == *.jks ]]; then
    sops_opts="--input-type binary --output-type binary"
  elif [[ "${file}" == *.json ]]; then
    sops_opts="--output-type json"
  fi
  # shellcheck disable=SC2086
  sops --decrypt ${sops_opts} "${cred_dir}/${file}.enc" > "${cred_dir}/${file}" \
    && echo "✅ ${file} decrypted successfully." \
    || { echo "❌ Failed to decrypt ${file}.enc" >&2; rm -f "${cred_dir}/${file}"; return 1; }
}

pushd "${CREDENTIALS_DIR}" >/dev/null

case "${ENVIRONMENT}" in
  staging)
    FOLDER="${ENVIRONMENT}"
    decrypt_if_needed "android/${PROJECT}/${FOLDER}" "upload.jks" || exit 1
    [[ -f "android/${PROJECT}/${FOLDER}/keystore.properties.enc" ]] && \
      decrypt_if_needed "android/${PROJECT}/${FOLDER}" "keystore.properties" || true
    [[ -f "android/${PROJECT}/${FOLDER}/google-services.json.enc" ]] && \
      decrypt_if_needed "android/${PROJECT}/${FOLDER}" "google-services.json" || true
    echo "✅ ${ENVIRONMENT} credentials ready"
    ;;
  prod)
    decrypt_if_needed "android/${PROJECT}/prod" "upload.jks" || exit 1
    [[ -f "android/${PROJECT}/prod/keystore.properties.enc" ]] && \
      decrypt_if_needed "android/${PROJECT}/prod" "keystore.properties" || true
    [[ -f "android/${PROJECT}/prod/google-services.json.enc" ]] && \
      decrypt_if_needed "android/${PROJECT}/prod" "google-services.json" || true
    echo "✅ prod credentials ready"
    ;;
  *) echo "❌ Unknown env: ${ENVIRONMENT}"; exit 1 ;;
esac

popd >/dev/null

echo "✅ Credentials ready in $CREDENTIALS_DIR/android/${PROJECT}/$ENVIRONMENT/"
echo "🔧 Build.gradle.kts will now read from the credentials directory"
echo "🚀 You can now build with: flutter build apk --flavor $ENVIRONMENT"
