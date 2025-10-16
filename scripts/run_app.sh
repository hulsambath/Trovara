#!/usr/bin/env bash
set -euo pipefail

# Enhanced Flutter app runner with credentials management integration
# Supports automatic credential decryption for local development
#
# Usage:
#   ./scripts/run_app.sh --noteminds          # Run with dev credentials (default)
#   ./scripts/run_app.sh --noteminds --prod   # Run with prod credentials
#   ./scripts/run_app.sh --noteminds --dev    # Explicitly run with dev credentials
#
# The script will:
# 1. Detect the environment (dev/prod) from arguments or default to dev
# 2. Automatically decrypt credentials if needed
# 3. Run Flutter with the appropriate configuration

# Default values
PROJECT="notemyminds"
ENVIRONMENT="dev"
DECRYPT_CREDENTIALS=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --noteminds|--notemyminds)
      PROJECT="notemyminds"
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
      echo "Usage: $0 [--noteminds|--notemyminds] [--prod|--dev] [--no-decrypt]"
      echo ""
      echo "Options:"
      echo "  --noteminds    Run NoteMyMinds app (legacy name)"
      echo "  --notemyminds  Run NoteMyMinds app (current name)"
      echo "  --prod         Use production credentials"
      echo "  --dev          Use development credentials (default)"
      echo "  --no-decrypt   Skip automatic credential decryption"
      echo "  --help         Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0 --notemyminds                    # Run with dev credentials"
      echo "  $0 --notemyminds --prod             # Run with prod credentials"
      echo "  $0 --notemyminds --no-decrypt       # Run without decrypting credentials"
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "💡 Use --help for usage information"
      exit 1
      ;;
  esac
done

echo "🚀 Starting NoteMyMinds ($ENVIRONMENT environment)..."

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

# Prepare Flutter run command
FLUTTER_CMD="flutter run --dart-define-from-file=configs/noteminds.json"

# Add flavor if specified (for build variants)
if [[ "$ENVIRONMENT" == "prod" ]]; then
  FLUTTER_CMD="$FLUTTER_CMD --flavor prod"
elif [[ "$ENVIRONMENT" == "dev" ]]; then
  FLUTTER_CMD="$FLUTTER_CMD --flavor dev"
fi

echo "📱 Running Flutter app..."
echo "🔧 Command: $FLUTTER_CMD"
echo ""

# Execute Flutter run
exec $FLUTTER_CMD
