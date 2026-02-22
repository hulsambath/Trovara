#!/usr/bin/env bash
set -euo pipefail

# Interactive Flutter app runner with credentials management integration
# Supports automatic credential decryption for local development

# Default values
PROJECT="trovara"
ENVIRONMENT=""
PLATFORM=""
DECRYPT_CREDENTIALS=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║          Trovara - Flutter App Runner                 ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

print_step() {
  echo -e "${GREEN}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

print_info() {
  echo -e "${YELLOW}$1${NC}"
}

# Function to show platform selection menu
select_platform() {
  print_header
  echo -e "${BLUE}📱 Platform Selection (step 1/2):${NC}"
  echo "  1) Mobile (Android/iOS)"
  echo "  2) Linux Desktop"
  echo "  3) Windows Desktop"
  echo "  4) macOS Desktop"
  echo "  5) Web"
  echo ""
  echo "  0) Exit"
  echo ""
  read -p "Select an option: " platform_choice

  case "$platform_choice" in
    1)
      PLATFORM=""  # Empty for mobile (will auto-detect)
      print_step "✅ Selected: Mobile (Android/iOS)"
      ;;
    2)
      PLATFORM="linux"
      print_step "✅ Selected: Linux Desktop"
      ;;
    3)
      PLATFORM="windows"
      print_step "✅ Selected: Windows Desktop"
      ;;
    4)
      PLATFORM="macos"
      print_step "✅ Selected: macOS Desktop"
      ;;
    5)
      PLATFORM="web"
      print_step "✅ Selected: Web"
      ;;
    0)
      print_info "👋 Goodbye!"
      exit 0
      ;;
    *)
      print_error "❌ Invalid option. Please try again."
      select_platform
      return
      ;;
  esac
}

# Function to show environment selection menu
select_environment() {
  echo ""
  print_header
  echo -e "${BLUE}║              Environment Selection (step 2/2)             ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "  1) Staging (staging) - Default"
  echo "  2) Production (prod)"
  echo "  0) Back"
  echo ""
  read -p "Select environment: " env_choice

  case "$env_choice" in
    1)
      ENVIRONMENT="staging"
      print_step "✅ Selected: Staging (staging)"
      ;;
    2)
      ENVIRONMENT="prod"
      print_step "✅ Selected: Production (prod)"
      ;;
    0)
      select_platform
      select_environment
      return
      ;;
    *)
      print_error "❌ Invalid option. Please try again."
      select_environment
      return
      ;;
  esac
}

# Function to show configuration summary and confirm
show_summary() {
  echo ""
  print_header
  echo -e "${BLUE}║                    Configuration Summary                   ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  PLATFORM_NAME="Mobile (Android/iOS)"
  if [[ "$PLATFORM" == "linux" ]]; then
    PLATFORM_NAME="Linux Desktop"
  elif [[ "$PLATFORM" == "windows" ]]; then
    PLATFORM_NAME="Windows Desktop"
  elif [[ "$PLATFORM" == "macos" ]]; then
    PLATFORM_NAME="macOS Desktop"
  elif [[ "$PLATFORM" == "web" ]]; then
    PLATFORM_NAME="Web"
  fi

  echo -e "${BLUE}📱 Platform:${NC} $PLATFORM_NAME"
  echo -e "${BLUE}🔧 Environment:${NC} $ENVIRONMENT"
  echo ""
  echo "  1) Start/Run"
  echo "  2) Change Configuration"
  echo "  0) Exit"
  echo ""
  read -p "Select an option: " confirm_choice

  case "$confirm_choice" in
    1)
      # Continue to run
      ;;
    2)
      select_platform
      select_environment
      show_summary
      return
      ;;
    0)
      print_info "👋 Goodbye!"
      exit 0
      ;;
    *)
      print_error "❌ Invalid option. Please try again."
      show_summary
      return
      ;;
  esac
}

# Start interactive selection
select_platform
select_environment
show_summary

# Now proceed with the actual run
echo ""
print_step "🚀 Starting Trovara ($ENVIRONMENT environment) on ${PLATFORM_NAME:-mobile}..."

# Check if credentials need to be decrypted
if [[ "$DECRYPT_CREDENTIALS" == "true" ]]; then
  print_step "🔐 Checking credentials for $ENVIRONMENT environment..."

  # Check if credentials project exists
  if [[ ! -d "../credentials" ]]; then
    print_error "❌ Credentials project not found at ../credentials"
    print_info "💡 Expected at: $(pwd)/../credentials"
    exit 1
  fi

  # Check if keystore script exists
  if [[ ! -f "scripts/keystore.sh" ]]; then
    print_error "❌ Keystore script not found: scripts/keystore.sh"
    exit 1
  fi

  # Check if credentials exist (plaintext for now, will be encrypted later)
  # Staging uses dev credentials, prod uses prod credentials
  CRED_ENV="$ENVIRONMENT"
  if [[ "$ENVIRONMENT" == "staging" ]]; then
    CRED_ENV="dev"
  fi
  CREDENTIALS_DIR="../credentials/android/$PROJECT/$CRED_ENV"

  # Check if plaintext credentials exist (already decrypted)
  if [[ -f "$CREDENTIALS_DIR/upload.jks" ]]; then
    print_step "✅ $ENVIRONMENT credentials found (plaintext)."
  elif [[ -f "$CREDENTIALS_DIR/upload.jks.enc" ]]; then
    # Credentials are SOPS-encrypted — decrypt them
    print_step "🔓 Decrypting SOPS-encrypted credentials for $ENVIRONMENT..."

    # Locate age private key
    AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
    CREDENTIALS_AGE_KEY="../credentials/scripts/age/trovara-age-key.txt"
    if [[ ! -f "$AGE_KEY_FILE" ]]; then
      if [[ -f "$CREDENTIALS_AGE_KEY" ]]; then
        mkdir -p "${HOME}/.config/sops/age"
        cp "$CREDENTIALS_AGE_KEY" "$AGE_KEY_FILE"
        print_step "📋 Installed age key to $AGE_KEY_FILE"
      else
        print_error "❌ Age private key not found."
        print_info "💡 Expected at: ~/.config/sops/age/keys.txt or $CREDENTIALS_AGE_KEY"
        exit 1
      fi
    fi

    export SOPS_AGE_KEY_FILE="$AGE_KEY_FILE"

    # Decrypt upload.jks (binary format)
    sops --decrypt --input-type binary --output-type binary "$CREDENTIALS_DIR/upload.jks.enc" > "$CREDENTIALS_DIR/upload.jks" \
      && print_step "✅ Decrypted upload.jks" \
      || { print_error "❌ Failed to decrypt upload.jks.enc"; exit 1; }

    # Decrypt keystore.properties
    if [[ -f "$CREDENTIALS_DIR/keystore.properties.enc" ]]; then
      sops --decrypt "$CREDENTIALS_DIR/keystore.properties.enc" > "$CREDENTIALS_DIR/keystore.properties" \
        && print_step "✅ Decrypted keystore.properties" \
        || { print_error "❌ Failed to decrypt keystore.properties.enc"; exit 1; }
    fi

    # Decrypt google-services.json if present
    if [[ -f "$CREDENTIALS_DIR/google-services.json.enc" ]]; then
      sops --decrypt --output-type json "$CREDENTIALS_DIR/google-services.json.enc" > "$CREDENTIALS_DIR/google-services.json" \
        && print_step "✅ Decrypted google-services.json" \
        || print_info "⚠️  Failed to decrypt google-services.json.enc (optional)"
    fi

    print_step "✅ $ENVIRONMENT credentials decrypted and ready to use"
  else
    print_info "⚠️  Credentials not found at: $CREDENTIALS_DIR/upload.jks(.enc)"
    print_info "💡 Generate credentials first:"
    echo "   cd ../credentials/scripts && ./generate-keystore.sh --project $PROJECT --env $CRED_ENV"
    exit 1
  fi
fi

# Determine config file based on environment
CONFIG_FILE="configs/trovara_${ENVIRONMENT}.json"

# Verify config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  print_error "❌ Configuration file not found: $CONFIG_FILE"
  print_info "💡 Make sure you have created config files for each environment:"
  echo "   - configs/trovara_staging.json (for staging)"
  echo "   - configs/trovara_prod.json (for prod)"
  exit 1
fi

print_step "📋 Using config: $CONFIG_FILE"

# Prepare Flutter command
FLUTTER_CMD="flutter run --dart-define-from-file=$CONFIG_FILE"

# Use the flavor-specific entry point if it exists (e.g. lib/main_staging.dart)
ENTRY_POINT="lib/main_${ENVIRONMENT}.dart"
if [[ -f "$ENTRY_POINT" ]]; then
  FLUTTER_CMD="$FLUTTER_CMD --target=$ENTRY_POINT"
fi

# Add platform target if specified
if [[ -n "$PLATFORM" ]]; then
  FLUTTER_CMD="$FLUTTER_CMD -d $PLATFORM"
fi

# Add flavor for mobile builds (Android uses flavor; iOS needs matching Xcode schemes)
if [[ -z "$PLATFORM" ]]; then
  FLUTTER_CMD="$FLUTTER_CMD --flavor $ENVIRONMENT"
fi

print_step "📱 Running Flutter app..."

# Check if this will target an iOS device
if [[ -z "$PLATFORM" ]]; then
  AVAILABLE_DEVICES=$(flutter devices 2>/dev/null | grep "ios" | grep -v "Simulator" || true)
  if [[ -n "$AVAILABLE_DEVICES" ]]; then
    echo ""
    print_info "ℹ️  iOS device detected!"
    print_info "💡 Note: For iOS, flavors work best when running from Xcode:"
    echo "   open ios/Runner.xcworkspace"
    echo "   Select scheme: staging or prod"
    echo ""
    print_info "⚠️  Attempting flutter run (may have issues with iOS flavors)..."
  fi
fi

echo ""
print_step "🔧 Command: $FLUTTER_CMD"
echo ""

# Execute Flutter run
exec $FLUTTER_CMD
