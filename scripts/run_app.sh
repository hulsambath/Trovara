#!/usr/bin/env bash
set -euo pipefail

# Interactive Flutter app runner with fast non-interactive defaults.
# Supports optional credential decryption for local development.

PROJECT="trovara"

# Inputs from environment (optional)
ENVIRONMENT="${ENVIRONMENT:-}"
DEVICE="${DEVICE:-}"
RUN_MODE="${RUN_MODE:-}"
DECRYPT_CREDENTIALS="${DECRYPT_CREDENTIALS:-}"

# Runtime flags
INTERACTIVE=false
QUICK_MODE=false
DRY_RUN=false

# Parsed argument candidates
EXPLICIT_ENV=""
EXPLICIT_RUN_MODE=""
EXPLICIT_DEVICE=""
EXPLICIT_DEVICE_SET=false
EXPLICIT_DECRYPT=""
EXPLICIT_DECRYPT_SET=false

PRESET_ENV=""
PRESET_RUN_MODE=""
PRESET_DEVICE=""
PRESET_DEVICE_SET=false
PRESET_DECRYPT=""
PRESET_DECRYPT_SET=false

# Saved state candidates
SAVED_ENV=""
SAVED_ENV_SET=false
SAVED_RUN_MODE=""
SAVED_RUN_MODE_SET=false
SAVED_DEVICE=""
SAVED_DEVICE_SET=false
SAVED_DECRYPT=""
SAVED_DECRYPT_SET=false

# Resolution source tracking
ENVIRONMENT_SOURCE="default"
RUN_MODE_SOURCE="default"
DEVICE_SOURCE="default"
DECRYPT_SOURCE="default"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CREDENTIALS_ROOT="$REPO_ROOT/../credentials"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/trovara"
STATE_FILE="$STATE_DIR/run_app_last.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

usage() {
  cat <<EOF
Usage: $0 [options] [device]

Run Trovara with environment-specific config and optional credential decryption.

Default behavior:
  - no prompts
  - reuse last successful run config when available
  - fallback to staging + debug + auto device

Options:
  -nm, --trovara      Trovara project (default)
  --prod              Production environment
  --dev, --staging    Staging environment
  --debug             Run in debug mode
  --profile           Run in profile mode
  --release           Run in release mode
  -d, --device <id>   Forward device selector to flutter run -d
  --android           Preset device: Android
  --ios               Preset device: iOS
  --web               Preset device: Web (chrome)
  --linux             Preset device: Linux desktop
  --windows           Preset device: Windows desktop
  --macos             Preset device: macOS desktop
  --staging-debug     Preset: staging + debug
  --prod-release      Preset: prod + release
  --with-creds        Enable credential decryption checks
  --decrypt           Alias for --with-creds
  --no-decrypt        Disable credential decryption checks
  --quick             Fast preset (staging + debug + auto device + no creds)
  --interactive       Force interactive selection menus
  --dry-run           Print command and exit without running Flutter
  -h, --help          Show this help

Positional device aliases:
  android | ios | linux | windows | macos | web | chrome | mobile

Examples:
  $0
  $0 --prod --release --android
  $0 --staging-debug --web
  $0 --with-creds --interactive
  $0 --quick
EOF
}

is_valid_environment() {
  case "$1" in
    staging|prod) return 0 ;;
    *) return 1 ;;
  esac
}

is_valid_run_mode() {
  case "$1" in
    debug|profile|release) return 0 ;;
    *) return 1 ;;
  esac
}

is_bool() {
  case "$1" in
    true|false) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_environment() {
  case "$1" in
    dev) echo "staging" ;;
    *) echo "$1" ;;
  esac
}

normalize_device() {
  case "$1" in
    web) echo "chrome" ;;
    *) echo "$1" ;;
  esac
}

is_non_mobile_target() {
  case "$1" in
    linux|windows|macos|web|chrome) return 0 ;;
    *) return 1 ;;
  esac
}

load_saved_state() {
  [[ -f "$STATE_FILE" ]] || return 0

  while IFS='=' read -r key value; do
    # Handle CRLF-safe values.
    value="${value%$'\r'}"
    case "$key" in
      ENVIRONMENT)
        value="$(normalize_environment "$value")"
        if is_valid_environment "$value"; then
          SAVED_ENV="$value"
          SAVED_ENV_SET=true
        fi
        ;;
      DEVICE)
        SAVED_DEVICE="$(normalize_device "$value")"
        SAVED_DEVICE_SET=true
        ;;
      RUN_MODE)
        if is_valid_run_mode "$value"; then
          SAVED_RUN_MODE="$value"
          SAVED_RUN_MODE_SET=true
        fi
        ;;
      DECRYPT_CREDENTIALS)
        if is_bool "$value"; then
          SAVED_DECRYPT="$value"
          SAVED_DECRYPT_SET=true
        fi
        ;;
    esac
  done < "$STATE_FILE"
}

save_run_state() {
  if ! mkdir -p "$STATE_DIR"; then
    print_info "⚠️  Could not create state directory: $STATE_DIR"
    return
  fi

  if ! cat > "$STATE_FILE" <<EOF
ENVIRONMENT=$ENVIRONMENT
DEVICE=$DEVICE
RUN_MODE=$RUN_MODE
DECRYPT_CREDENTIALS=$DECRYPT_CREDENTIALS
EOF
  then
    print_info "⚠️  Could not write state file: $STATE_FILE"
  fi
}

saved_device_is_available() {
  local requested="$1"

  if ! command -v flutter >/dev/null 2>&1; then
    return 2
  fi

  local devices_json
  devices_json="$(flutter devices --machine 2>/dev/null || true)"
  if [[ -z "$devices_json" ]]; then
    return 2
  fi

  case "$requested" in
    android)
      grep -q '"targetPlatform":"android-' <<< "$devices_json"
      ;;
    ios)
      grep -q '"targetPlatform":"ios"' <<< "$devices_json"
      ;;
    chrome|web)
      grep -q '"targetPlatform":"web-' <<< "$devices_json"
      ;;
    linux)
      grep -q '"targetPlatform":"linux' <<< "$devices_json"
      ;;
    windows)
      grep -q '"targetPlatform":"windows' <<< "$devices_json"
      ;;
    macos)
      grep -q '"id":"macos"' <<< "$devices_json" || grep -q '"targetPlatform":"darwin' <<< "$devices_json"
      ;;
    *)
      grep -Fq "\"id\":\"$requested\"" <<< "$devices_json"
      ;;
  esac
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -nm|--trovara)
        shift
        ;;
      --prod)
        EXPLICIT_ENV="prod"
        shift
        ;;
      --dev|--staging)
        EXPLICIT_ENV="staging"
        shift
        ;;
      --debug|--profile|--release)
        EXPLICIT_RUN_MODE="${1#--}"
        shift
        ;;
      -d|--device)
        if [[ $# -lt 2 ]]; then
          print_error "❌ Missing value for $1"
          exit 1
        fi
        EXPLICIT_DEVICE="$(normalize_device "$2")"
        EXPLICIT_DEVICE_SET=true
        shift 2
        ;;
      --android)
        PRESET_DEVICE="android"
        PRESET_DEVICE_SET=true
        shift
        ;;
      --ios)
        PRESET_DEVICE="ios"
        PRESET_DEVICE_SET=true
        shift
        ;;
      --web)
        PRESET_DEVICE="chrome"
        PRESET_DEVICE_SET=true
        shift
        ;;
      --linux)
        PRESET_DEVICE="linux"
        PRESET_DEVICE_SET=true
        shift
        ;;
      --windows)
        PRESET_DEVICE="windows"
        PRESET_DEVICE_SET=true
        shift
        ;;
      --macos)
        PRESET_DEVICE="macos"
        PRESET_DEVICE_SET=true
        shift
        ;;
      --staging-debug)
        PRESET_ENV="staging"
        PRESET_RUN_MODE="debug"
        shift
        ;;
      --prod-release)
        PRESET_ENV="prod"
        PRESET_RUN_MODE="release"
        shift
        ;;
      --with-creds|--decrypt)
        EXPLICIT_DECRYPT="true"
        EXPLICIT_DECRYPT_SET=true
        shift
        ;;
      --no-decrypt)
        EXPLICIT_DECRYPT="false"
        EXPLICIT_DECRYPT_SET=true
        shift
        ;;
      --quick)
        QUICK_MODE=true
        INTERACTIVE=false
        PRESET_ENV="staging"
        PRESET_RUN_MODE="debug"
        PRESET_DEVICE=""
        PRESET_DEVICE_SET=true
        PRESET_DECRYPT="false"
        PRESET_DECRYPT_SET=true
        shift
        ;;
      --interactive)
        INTERACTIVE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      android|ios|linux|windows|macos|web|chrome)
        EXPLICIT_DEVICE="$(normalize_device "$1")"
        EXPLICIT_DEVICE_SET=true
        shift
        ;;
      mobile)
        EXPLICIT_DEVICE=""
        EXPLICIT_DEVICE_SET=true
        shift
        ;;
      *)
        print_error "❌ Unknown option: $1"
        echo ""
        usage
        exit 1
        ;;
    esac
  done
}

resolve_config() {
  # ENVIRONMENT
  if [[ -n "$EXPLICIT_ENV" ]]; then
    ENVIRONMENT="$EXPLICIT_ENV"
    ENVIRONMENT_SOURCE="explicit"
  elif [[ -n "$PRESET_ENV" ]]; then
    ENVIRONMENT="$PRESET_ENV"
    ENVIRONMENT_SOURCE="preset"
  elif [[ -n "$ENVIRONMENT" ]]; then
    ENVIRONMENT="$(normalize_environment "$ENVIRONMENT")"
    ENVIRONMENT_SOURCE="env"
  elif [[ "$SAVED_ENV_SET" == "true" ]]; then
    ENVIRONMENT="$SAVED_ENV"
    ENVIRONMENT_SOURCE="saved"
  else
    ENVIRONMENT="staging"
    ENVIRONMENT_SOURCE="default"
  fi

  if ! is_valid_environment "$ENVIRONMENT"; then
    print_error "❌ Invalid environment: $ENVIRONMENT (expected staging|prod)"
    exit 1
  fi

  # RUN MODE
  if [[ -n "$EXPLICIT_RUN_MODE" ]]; then
    RUN_MODE="$EXPLICIT_RUN_MODE"
    RUN_MODE_SOURCE="explicit"
  elif [[ -n "$PRESET_RUN_MODE" ]]; then
    RUN_MODE="$PRESET_RUN_MODE"
    RUN_MODE_SOURCE="preset"
  elif [[ -n "$RUN_MODE" ]]; then
    RUN_MODE_SOURCE="env"
  elif [[ "$SAVED_RUN_MODE_SET" == "true" ]]; then
    RUN_MODE="$SAVED_RUN_MODE"
    RUN_MODE_SOURCE="saved"
  else
    RUN_MODE="debug"
    RUN_MODE_SOURCE="default"
  fi

  if ! is_valid_run_mode "$RUN_MODE"; then
    print_error "❌ Invalid RUN_MODE: $RUN_MODE (expected debug|profile|release)"
    exit 1
  fi

  # CREDENTIALS
  if [[ "$EXPLICIT_DECRYPT_SET" == "true" ]]; then
    DECRYPT_CREDENTIALS="$EXPLICIT_DECRYPT"
    DECRYPT_SOURCE="explicit"
  elif [[ "$PRESET_DECRYPT_SET" == "true" ]]; then
    DECRYPT_CREDENTIALS="$PRESET_DECRYPT"
    DECRYPT_SOURCE="preset"
  elif [[ -n "$DECRYPT_CREDENTIALS" ]]; then
    DECRYPT_SOURCE="env"
  elif [[ "$SAVED_DECRYPT_SET" == "true" ]]; then
    DECRYPT_CREDENTIALS="$SAVED_DECRYPT"
    DECRYPT_SOURCE="saved"
  else
    DECRYPT_CREDENTIALS="false"
    DECRYPT_SOURCE="default"
  fi

  if ! is_bool "$DECRYPT_CREDENTIALS"; then
    print_error "❌ Invalid DECRYPT_CREDENTIALS value: $DECRYPT_CREDENTIALS (expected true|false)"
    exit 1
  fi

  # DEVICE
  if [[ "$EXPLICIT_DEVICE_SET" == "true" ]]; then
    DEVICE="$EXPLICIT_DEVICE"
    DEVICE_SOURCE="explicit"
  elif [[ "$PRESET_DEVICE_SET" == "true" ]]; then
    DEVICE="$PRESET_DEVICE"
    DEVICE_SOURCE="preset"
  elif [[ -n "$DEVICE" ]]; then
    DEVICE="$(normalize_device "$DEVICE")"
    DEVICE_SOURCE="env"
  elif [[ "$SAVED_DEVICE_SET" == "true" ]]; then
    DEVICE="$SAVED_DEVICE"
    DEVICE_SOURCE="saved"
  else
    DEVICE=""
    DEVICE_SOURCE="default"
  fi
}

select_device() {
  print_header
  echo -e "${BLUE}📱 Platform Selection (step 1/2):${NC}"
  echo "  1) Mobile (Android/iOS)"
  echo "  2) Android"
  echo "  3) iOS"
  echo "  4) Linux Desktop"
  echo "  5) Windows Desktop"
  echo "  6) macOS Desktop"
  echo "  7) Web"
  echo ""
  echo "  0) Exit"
  echo ""
  read -r -p "Select an option: " platform_choice

  case "$platform_choice" in
    1)
      DEVICE=""
      print_step "✅ Selected: Mobile (auto-detect Android/iOS)"
      ;;
    2)
      DEVICE="android"
      print_step "✅ Selected: Android"
      ;;
    3)
      DEVICE="ios"
      print_step "✅ Selected: iOS"
      ;;
    4)
      DEVICE="linux"
      print_step "✅ Selected: Linux Desktop"
      ;;
    5)
      DEVICE="windows"
      print_step "✅ Selected: Windows Desktop"
      ;;
    6)
      DEVICE="macos"
      print_step "✅ Selected: macOS Desktop"
      ;;
    7)
      DEVICE="chrome"
      print_step "✅ Selected: Web"
      ;;
    0)
      print_info "👋 Goodbye!"
      exit 0
      ;;
    *)
      print_error "❌ Invalid option. Please try again."
      select_device
      return
      ;;
  esac
}

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
  read -r -p "Select environment: " env_choice

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
      select_device
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

show_summary() {
  local device_name='Mobile (auto-detect Android/iOS)'
  if [[ -n "$DEVICE" ]]; then
    case "$DEVICE" in
      android) device_name='Android' ;;
      ios) device_name='iOS' ;;
      linux) device_name='Linux Desktop' ;;
      windows) device_name='Windows Desktop' ;;
      macos) device_name='macOS Desktop' ;;
      chrome|web) device_name='Web' ;;
      *) device_name="$DEVICE" ;;
    esac
  fi

  echo ""
  print_header
  echo -e "${BLUE}║                    Configuration Summary                   ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BLUE}📱 Target:${NC} $device_name"
  echo -e "${BLUE}🔧 Environment:${NC} $ENVIRONMENT"
  echo -e "${BLUE}🏃 Run mode:${NC} $RUN_MODE"
  echo -e "${BLUE}🔐 Credentials:${NC} $DECRYPT_CREDENTIALS"
  echo ""
  echo "  1) Start/Run"
  echo "  2) Change Configuration"
  echo "  0) Exit"
  echo ""
  read -r -p "Select an option: " confirm_choice

  case "$confirm_choice" in
    1)
      ;;
    2)
      select_device
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

parse_args "$@"
load_saved_state
resolve_config

if [[ "$INTERACTIVE" == "true" ]]; then
  select_device
  select_environment
  ENVIRONMENT_SOURCE="interactive"
  DEVICE_SOURCE="interactive"
  show_summary
fi

cd "$REPO_ROOT"

echo ""
print_step "🚀 Starting Trovara ($ENVIRONMENT environment)..."

if [[ "$ENVIRONMENT_SOURCE" == "saved" || "$DEVICE_SOURCE" == "saved" || "$RUN_MODE_SOURCE" == "saved" || "$DECRYPT_SOURCE" == "saved" ]]; then
  print_info "↺ Reusing last saved run configuration"
fi

if [[ "$QUICK_MODE" == "true" ]]; then
  print_info "⚡ Quick preset enabled"
fi

# If target device comes from saved state and is unavailable, fallback to auto-detect.
if [[ "$DEVICE_SOURCE" == "saved" && -n "$DEVICE" ]]; then
  if saved_device_is_available "$DEVICE"; then
    :
  else
    availability_status=$?
    if [[ "$availability_status" -eq 1 ]]; then
      print_info "⚠️  Saved device '$DEVICE' is unavailable. Falling back to auto-detect."
      DEVICE=""
    else
      print_info "⚠️  Could not verify saved device '$DEVICE'. Keeping saved target."
    fi
  fi
fi

# Check if credentials need to be decrypted
if [[ "$DECRYPT_CREDENTIALS" == "true" ]]; then
  print_step "🔐 Checking credentials for $ENVIRONMENT environment..."

  if [[ ! -d "$CREDENTIALS_ROOT" ]]; then
    print_error "❌ Credentials project not found at $CREDENTIALS_ROOT"
    exit 1
  fi

  if [[ ! -f "$SCRIPT_DIR/keystore.sh" ]]; then
    print_error "❌ Keystore script not found: $SCRIPT_DIR/keystore.sh"
    exit 1
  fi

  CRED_ENV="$ENVIRONMENT"
  CREDENTIALS_DIR="$CREDENTIALS_ROOT/android/$PROJECT/$CRED_ENV"

  if [[ -f "$CREDENTIALS_DIR/upload.jks" ]]; then
    print_step "✅ $ENVIRONMENT credentials found (plaintext)."
  elif [[ -f "$CREDENTIALS_DIR/upload.jks.enc" ]]; then
    print_step "🔓 Decrypting SOPS-encrypted credentials for $ENVIRONMENT..."

    AGE_KEY_FILE="${HOME}/.config/sops/age/keys.txt"
    CREDENTIALS_AGE_KEY="$CREDENTIALS_ROOT/scripts/age/trovara-age-key.txt"
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

    sops --decrypt --input-type binary --output-type binary "$CREDENTIALS_DIR/upload.jks.enc" > "$CREDENTIALS_DIR/upload.jks" \
      && print_step "✅ Decrypted upload.jks" \
      || { print_error "❌ Failed to decrypt upload.jks.enc"; exit 1; }

    if [[ -f "$CREDENTIALS_DIR/keystore.properties.enc" ]]; then
      sops --decrypt "$CREDENTIALS_DIR/keystore.properties.enc" > "$CREDENTIALS_DIR/keystore.properties" \
        && print_step "✅ Decrypted keystore.properties" \
        || { print_error "❌ Failed to decrypt keystore.properties.enc"; exit 1; }
    fi

    if [[ -f "$CREDENTIALS_DIR/google-services.json.enc" ]]; then
      sops --decrypt --output-type json "$CREDENTIALS_DIR/google-services.json.enc" > "$CREDENTIALS_DIR/google-services.json" \
        && print_step "✅ Decrypted google-services.json" \
        || print_info "⚠️  Failed to decrypt google-services.json.enc (optional)"
    fi

    print_step "✅ $ENVIRONMENT credentials decrypted and ready to use"
  else
    print_info "⚠️  Credentials not found at: $CREDENTIALS_DIR/upload.jks(.enc)"
    print_info "💡 Generate credentials first:"
    echo "   cd $CREDENTIALS_ROOT/scripts && ./generate-keystore.sh --project $PROJECT --env $CRED_ENV"
    exit 1
  fi
fi

CONFIG_FILE="$REPO_ROOT/configs/trovara_${ENVIRONMENT}.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  print_error "❌ Configuration file not found: $CONFIG_FILE"
  print_info "💡 Make sure you have created config files for each environment:"
  echo "   - configs/trovara_staging.json (for staging)"
  echo "   - configs/trovara_prod.json (for prod)"
  exit 1
fi

print_step "📋 Using config: $CONFIG_FILE"

FLUTTER_CMD=(flutter run "--dart-define-from-file=$CONFIG_FILE")

ENTRY_POINT="$REPO_ROOT/lib/main_${ENVIRONMENT}.dart"
if [[ -f "$ENTRY_POINT" ]]; then
  FLUTTER_CMD+=(--target="$ENTRY_POINT")
fi

if [[ -z "$DEVICE" ]] || ! is_non_mobile_target "$DEVICE"; then
  FLUTTER_CMD+=(--flavor "$ENVIRONMENT")
fi

if [[ -n "$DEVICE" ]]; then
  FLUTTER_CMD+=(-d "$DEVICE")
fi

case "$RUN_MODE" in
  release)
    FLUTTER_CMD+=(--release)
    ;;
  profile)
    FLUTTER_CMD+=(--profile)
    ;;
  debug)
    ;;
esac

save_run_state

echo ""
print_step "🔧 Command:"
printf '   %q ' "${FLUTTER_CMD[@]}"
echo ""
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  print_info "ℹ️  Dry run complete. Command not executed."
  exit 0
fi

exec "${FLUTTER_CMD[@]}"
