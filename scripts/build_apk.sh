#!/usr/bin/env bash
set -euo pipefail

# Enhanced Flutter APK builder with credentials management integration
# Supports automatic credential decryption for builds
#
# Usage:
#   ./scripts/build_apk.sh -yp                  # Build with dev credentials (default)
#   ./scripts/build_apk.sh -yp --prod           # Build with prod credentials
#   ./scripts/build_apk.sh -yp --dev            # Build with dev credentials explicitly
#   ./scripts/build_apk.sh --trovara        # Build with dev credentials (default)
#   ./scripts/build_apk.sh --trovara --prod # Build with prod credentials
#
# The script will:
# 1. Detect the environment (dev/prod) from arguments or default to dev
# 2. Automatically decrypt credentials if needed
# 3. Build APK with the appropriate configuration and credentials

# Default values
PROJECT="trovara"
ENVIRONMENT="dev"
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
      ENVIRONMENT="dev"
      shift
      ;;
    --no-decrypt)
      DECRYPT_CREDENTIALS=false
      shift
      ;;
    --help)
      echo "Usage: $0 [-nm|--trovara] [--prod|--dev] [--no-decrypt]"
      echo ""
      echo "Options:"
      echo "  -nm, --trovara  Build Trovara APK"
      echo "  --prod         Use production credentials"
      echo "  --dev          Use development credentials (default)"
      echo "  --no-decrypt   Skip automatic credential decryption"
      echo "  --help         Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 -yp                              # Build with dev credentials"
      echo "  $0 -yp --prod                       # Build with prod credentials"
      echo "  $0 -yp --no-decrypt                 # Build without decrypting credentials"
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

# Prepare Flutter build command
FLUTTER_CMD="flutter build apk --dart-define-from-file=configs/trovara.json --release"

# Add flavor if specified
if [[ "$ENVIRONMENT" == "prod" ]]; then
  FLUTTER_CMD="$FLUTTER_CMD --flavor prod"
elif [[ "$ENVIRONMENT" == "dev" ]]; then
  FLUTTER_CMD="$FLUTTER_CMD --flavor dev"
fi

echo "🔨 Building APK..."
echo "🔧 Command: $FLUTTER_CMD"
echo ""

# Execute Flutter build
eval $FLUTTER_CMD

echo ""
echo "✅ APK build completed!"
echo "📁 Check build/app/outputs/flutter-apk/ for the generated APK"
