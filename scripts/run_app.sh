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
  echo "  1) Development (dev) - Default"
  echo "  2) Production (prod)"
  echo "  0) Back"
  echo ""
  read -p "Select environment: " env_choice

  case "$env_choice" in
    1)
      ENVIRONMENT="dev"
      print_step "✅ Selected: Development (dev)"
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
  CREDENTIALS_DIR="../credentials/android/$PROJECT/$ENVIRONMENT"
  if [[ ! -f "$CREDENTIALS_DIR/upload.jks" ]]; then
    print_info "⚠️  Credentials not found at: $CREDENTIALS_DIR/upload.jks"
    print_info "💡 Generate credentials first:"
    echo "   cd ../credentials/scripts && ./generate-keystore.sh --project $PROJECT --env $ENVIRONMENT"
    echo "   # Then encrypt the files with SOPS when ready"
    exit 1
  fi

  # For now, work with plaintext credentials (will be encrypted later)
  print_step "✅ $ENVIRONMENT credentials found and ready to use"
fi

# Determine config file based on environment
CONFIG_FILE="configs/trovara_${ENVIRONMENT}.json"

# Verify config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  print_error "❌ Configuration file not found: $CONFIG_FILE"
  print_info "💡 Make sure you have created config files for each environment:"
  echo "   - configs/trovara_dev.json (for dev)"
  echo "   - configs/trovara_prod.json (for prod)"
  exit 1
fi

print_step "📋 Using config: $CONFIG_FILE"

# Prepare Flutter command
FLUTTER_CMD="flutter run --dart-define-from-file=$CONFIG_FILE"

# Add platform target if specified
if [[ -n "$PLATFORM" ]]; then
  FLUTTER_CMD="$FLUTTER_CMD -d $PLATFORM"
fi

# Note: Flavors are disabled for iOS until custom schemes are configured in Xcode
# Add flavor if specified (for build variants - mainly for Android)
# if [[ -z "$PLATFORM" ]]; then
#   if [[ "$ENVIRONMENT" == "prod" ]]; then
#     FLUTTER_CMD="$FLUTTER_CMD --flavor prod"
#   elif [[ "$ENVIRONMENT" == "dev" ]]; then
#     FLUTTER_CMD="$FLUTTER_CMD --flavor dev"
#   fi
# fi

print_step "📱 Running Flutter app..."

# Check if this will target an iOS device
if [[ -z "$PLATFORM" ]]; then
  AVAILABLE_DEVICES=$(flutter devices 2>/dev/null | grep "ios" | grep -v "Simulator" || true)
  if [[ -n "$AVAILABLE_DEVICES" ]]; then
    echo ""
    print_info "ℹ️  iOS device detected!"
    print_info "💡 Note: For iOS, flavors work best when running from Xcode:"
    echo "   open ios/Runner.xcworkspace"
    echo "   Select scheme: $ENVIRONMENT"
    echo ""
    print_info "⚠️  Attempting flutter run (may have issues with iOS flavors)..."
  fi
fi

echo ""
print_step "🔧 Command: $FLUTTER_CMD"
echo ""

# Execute Flutter run
exec $FLUTTER_CMD
