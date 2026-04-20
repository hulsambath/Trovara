#!/usr/bin/env bash
set -euo pipefail

# Flutter App Bundle (.aab) builder with optional credential decryption
#
# Usage:
#   ./scripts/build_appbundle.sh                # Build staging AAB (default)
#   ./scripts/build_appbundle.sh --prod         # Build production AAB
#   ./scripts/build_appbundle.sh --no-decrypt   # Skip SOPS / keystore.sh
#
# Quicker via CLI hub:
#   dev build aab                               # Build staging AAB
#   dev build aab prod                          # Build production AAB
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
      echo "Usage: $0 [--trovara] [--prod|--dev] [--no-decrypt]"
      echo ""
      echo "Build Android App Bundle (.aab) for Trovara"
      echo ""
      echo "Options:"
      echo "  --trovara    Trovara project (default)"
      echo "  --prod       Production environment"
      echo "  --dev        Staging environment (alias)"
      echo "  --no-decrypt Do not run scripts/keystore.sh"
      echo "  --help       Show this help"
      echo ""
      echo "Examples:"
      echo "  $0               # Build staging AAB (default)"
      echo "  $0 --prod        # Build production AAB"
      echo ""
      echo "Quicker via CLI hub:"
      echo "  dev build aab    # Build staging AAB"
      echo "  dev build aab prod  # Build production AAB"
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
