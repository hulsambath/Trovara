#!/usr/bin/env bash
set -euo pipefail

# Flutter App Bundle (.aab) builder with optional credential decryption
#
# Usage:
#   ./scripts/build_appbundle.sh                  # staging + decrypt
#   ./scripts/build_appbundle.sh --prod           # prod + decrypt
#   ./scripts/build_appbundle.sh --no-decrypt     # skip SOPS / keystore.sh
#
# Requires ../credentials (Android signing) when using decrypt.

PROJECT="trovara"
ENVIRONMENT="staging"
DECRYPT_CREDENTIALS=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -nm|--trovara)
      PROJECT="trovara"
      shift
      ;;
    --prod)
      ENVIRONMENT="prod"
      shift
      ;;
    --dev)
      ENVIRONMENT="staging"
      shift
      ;;
    --no-decrypt)
      DECRYPT_CREDENTIALS=false
      shift
      ;;
    --help)
      echo "Usage: $0 [-nm|--trovara] [--prod|--dev] [--no-decrypt]"
      echo ""
      echo "Build a release Android App Bundle (.aab) with the same flavors as build_apk.sh."
      echo ""
      echo "Options:"
      echo "  -nm, --trovara   Trovara project (default)"
      echo "  --prod           Production flavor + credentials"
      echo "  --dev            Staging flavor (alias)"
      echo "  --no-decrypt     Do not run scripts/keystore.sh"
      echo "  --help           Show this help"
      echo ""
      echo "Output:"
      echo "  build/app/outputs/bundle/<flavor>Release/app-<flavor>-release.aab"
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "💡 Use --help for usage information"
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT"

echo "📦 Building Trovara App Bundle ($ENVIRONMENT environment)..."

if [[ "$DECRYPT_CREDENTIALS" == "true" ]]; then
  echo "🔐 Decrypting Android credentials for $ENVIRONMENT..."
  if [[ ! -d "../credentials" ]]; then
    echo "❌ Credentials repo not found at: $REPO_ROOT/../credentials"
    exit 1
  fi
  if [[ ! -f "scripts/keystore.sh" ]]; then
    echo "❌ scripts/keystore.sh not found"
    exit 1
  fi
  ./scripts/keystore.sh --env "$ENVIRONMENT"
fi

CREDENTIALS_DIR="../credentials/android/$PROJECT/$ENVIRONMENT"
if [[ ! -f "$CREDENTIALS_DIR/upload.jks" ]]; then
  echo "❌ Keystore not found: $CREDENTIALS_DIR/upload.jks"
  echo "💡 Decrypt (remove --no-decrypt) or run: ./scripts/keystore.sh --env $ENVIRONMENT"
  exit 1
fi

CONFIG_FILE="configs/trovara_${ENVIRONMENT}.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Configuration file not found: $CONFIG_FILE"
  exit 1
fi

echo "📋 Using config: $CONFIG_FILE"

FLUTTER_CMD=(flutter build appbundle
  --dart-define-from-file="$CONFIG_FILE"
  --release)

if [[ "$ENVIRONMENT" == "prod" ]]; then
  FLUTTER_CMD+=(--flavor prod --target=lib/main_prod.dart)
else
  FLUTTER_CMD+=(--flavor staging --target=lib/main_staging.dart)
fi

echo "🔨 Building App Bundle..."
printf '🔧 '; printf '%q ' "${FLUTTER_CMD[@]}"; echo; echo

"${FLUTTER_CMD[@]}"

echo ""
echo "✅ App Bundle build completed!"
echo "📁 build/app/outputs/bundle/${ENVIRONMENT}Release/ (look for app-${ENVIRONMENT}-release.aab)"
