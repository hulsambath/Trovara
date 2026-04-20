#!/usr/bin/env bash
set -euo pipefail

# Enhanced Flutter APK builder with credentials management integration
# Supports automatic credential decryption for builds
#
# Usage:
#   ./scripts/build_apk.sh                      # Build staging APK (default)
#   ./scripts/build_apk.sh --prod               # Build prod APK
#   ./scripts/build_apk.sh --trovara            # Build staging APK (default)
#   ./scripts/build_apk.sh --trovara --prod     # Build prod APK
#
# Quicker via CLI hub:
#   dev build apk                               # Build staging APK
#   dev build apk prod                          # Build prod APK
#
# The script will:
# 1. Detect the environment (staging/prod) from arguments or default to staging
# 2. Automatically decrypt credentials if needed
# 3. Build APK with the appropriate configuration and credentials

# Default values
PROJECT="trovara"
ENVIRONMENT="staging"
DECRYPT_CREDENTIALS=true

# Parse arguments
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
      echo "Build Android APK for Trovara"
      echo ""
      echo "Options:"
      echo "  --trovara      Trovara project (default)"
      echo "  --prod         Production environment"
      echo "  --dev          Staging environment (alias)"
      echo "  --no-decrypt   Skip credential decryption"
      echo "  --help         Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                  # Build staging APK (default)"
      echo "  $0 --prod           # Build production APK"
      echo "  $0 --no-decrypt     # Build without decrypting credentials"
      echo ""
      echo "Quicker via CLI hub:"
      echo "  dev build apk       # Build staging APK"
      echo "  dev build apk prod  # Build production APK"
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "💡 Use --help for usage information"
      exit 1
      ;;
  esac
done

echo "📦 Building Trovara APK ($ENVIRONMENT environment)..."

# Check if credentials need to be decrypted
if [[ "$DECRYPT_CREDENTIALS" == "true" ]]; then
  echo "🔐 Checking credentials for $ENVIRONMENT environment..."

  # Check if credentials project exists
  if [[ ! -d "../credentials" ]]; then
    echo "❌ Credentials project not found at ../credentials"
    echo "💡 Expected at: $(pwd)/../credentials"
    exit 1
  fi

  # Check if keystore script exists
  if [[ ! -f "scripts/keystore.sh" ]]; then
    echo "❌ Keystore script not found: scripts/keystore.sh"
    exit 1
  fi

  # Check if credentials exist (plaintext for now, will be encrypted later)
  CREDENTIALS_DIR="../credentials/android/$PROJECT/$ENVIRONMENT"
  if [[ ! -f "$CREDENTIALS_DIR/upload.jks" ]]; then
    echo "⚠️  Credentials not found at: $CREDENTIALS_DIR/upload.jks"
    echo "💡 Generate credentials first:"
    echo "   cd ../credentials/scripts && ./generate-keystore.sh --project $PROJECT --env $ENVIRONMENT"
    echo "   # Then encrypt the files with SOPS when ready"
    exit 1
  fi

  # For now, work with plaintext credentials (will be encrypted later)
  echo "✅ $ENVIRONMENT credentials found and ready to use"
fi

# Determine config file based on environment
CONFIG_FILE="configs/trovara_${ENVIRONMENT}.json"

# Verify config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Configuration file not found: $CONFIG_FILE"
  echo "💡 Make sure you have created config files for each environment:"
  echo "   - configs/trovara_staging.json (for staging)"
  echo "   - configs/trovara_prod.json (for prod)"
  exit 1
fi

echo "📋 Using config: $CONFIG_FILE"

# Prepare Flutter build command
FLUTTER_CMD="flutter build apk --dart-define-from-file=$CONFIG_FILE --release"

# Add flavor and entry point
if [[ "$ENVIRONMENT" == "prod" ]]; then
  FLUTTER_CMD="$FLUTTER_CMD --flavor prod --target=lib/main_prod.dart"
else
  FLUTTER_CMD="$FLUTTER_CMD --flavor staging --target=lib/main_staging.dart"
fi

echo "🔨 Building APK..."
echo "🔧 Command: $FLUTTER_CMD"
echo ""

# Execute Flutter build
eval $FLUTTER_CMD

echo ""
echo "✅ APK build completed!"
echo "📁 Check build/app/outputs/flutter-apk/ for the generated APK"
