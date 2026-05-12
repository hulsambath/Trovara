#!/usr/bin/env bash
set -euo pipefail

# Android-only Shorebird release/patch helper for Trovara.
# Mirrors scripts/run_app.sh behavior: fast defaults, optional interactive flow,
# environment presets, saved last config, and dry-run mode.

PROJECT='trovara'

# Optional env inputs
ENVIRONMENT="${ENVIRONMENT:-}"
DECRYPT_CREDENTIALS="${DECRYPT_CREDENTIALS:-}"
SHOREBIRD_ACTION="${SHOREBIRD_ACTION:-}"
RELEASE_VERSION="${RELEASE_VERSION:-}"

# Runtime flags
INTERACTIVE=false
DRY_RUN=false
QUICK_MODE=false

# Parsed args (explicit)
EXPLICIT_ENV=''
EXPLICIT_ENV_SET=false
EXPLICIT_DECRYPT=''
EXPLICIT_DECRYPT_SET=false
EXPLICIT_ACTION=''
EXPLICIT_ACTION_SET=false
EXPLICIT_RELEASE_VERSION=''
EXPLICIT_RELEASE_VERSION_SET=false

# Presets
PRESET_ENV=''
PRESET_ENV_SET=false
PRESET_DECRYPT=''
PRESET_DECRYPT_SET=false
PRESET_ACTION=''
PRESET_ACTION_SET=false

# Saved state candidates
SAVED_ENV=''
SAVED_ENV_SET=false
SAVED_DECRYPT=''
SAVED_DECRYPT_SET=false
SAVED_ACTION=''
SAVED_ACTION_SET=false
SAVED_RELEASE_VERSION=''
SAVED_RELEASE_VERSION_SET=false

# Source tracking
ENVIRONMENT_SOURCE='default'
DECRYPT_SOURCE='default'
ACTION_SOURCE='default'
RELEASE_VERSION_SOURCE='default'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/trovara"
STATE_FILE="$STATE_DIR/shorebird_android_last.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║      Trovara - Shorebird Android Release/Patch Runner     ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ''
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
Usage: $0 [options]

Run Shorebird release/patch for Android (Trovara).

Default behavior:
  - no prompts
  - reuse last successful Shorebird config when available
  - fallback to staging + release + decrypt creds

Options:
  -nm, --trovara            Trovara project (default)
  --prod                    Production environment
  --dev, --staging          Staging environment
  --release                 Shorebird release action (default)
  --patch                   Shorebird patch action
  --release-version <ver>   Patch a specific release version
  --staging-release         Preset: staging + release
  --prod-release            Preset: prod + release
  --staging-patch           Preset: staging + patch
  --prod-patch              Preset: prod + patch
  --with-creds              Decrypt Android credentials before Shorebird run
  --decrypt                 Alias for --with-creds
  --no-decrypt              Skip credential decryption
  --quick                   Fast preset (staging + release + no prompts)
  --interactive             Force interactive selection menus
  --dry-run                 Print command and exit without running Shorebird
  -h, --help                Show this help

Examples:
  $0
  $0 --prod-release
  $0 --patch --prod --release-version 1.0.0+10
  $0 --staging-patch --no-decrypt
EOF
}

is_valid_environment() {
  case "$1" in
    staging|prod) return 0 ;;
    *) return 1 ;;
  esac
}

is_valid_action() {
  case "$1" in
    release|patch) return 0 ;;
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
    dev) echo 'staging' ;;
    *) echo "$1" ;;
  esac
}

load_saved_state() {
  [[ -f "$STATE_FILE" ]] || return 0

  while IFS='=' read -r key value; do
    value="${value%$'\r'}"
    case "$key" in
      ENVIRONMENT)
        value="$(normalize_environment "$value")"
        if is_valid_environment "$value"; then
          SAVED_ENV="$value"
          SAVED_ENV_SET=true
        fi
        ;;
      DECRYPT_CREDENTIALS)
        if is_bool "$value"; then
          SAVED_DECRYPT="$value"
          SAVED_DECRYPT_SET=true
        fi
        ;;
      SHOREBIRD_ACTION)
        if is_valid_action "$value"; then
          SAVED_ACTION="$value"
          SAVED_ACTION_SET=true
        fi
        ;;
      RELEASE_VERSION)
        SAVED_RELEASE_VERSION="$value"
        SAVED_RELEASE_VERSION_SET=true
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
DECRYPT_CREDENTIALS=$DECRYPT_CREDENTIALS
SHOREBIRD_ACTION=$SHOREBIRD_ACTION
RELEASE_VERSION=$RELEASE_VERSION
EOF
  then
    print_info "⚠️  Could not write state file: $STATE_FILE"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -nm|--trovara)
        shift
        ;;
      --prod)
        EXPLICIT_ENV='prod'
        EXPLICIT_ENV_SET=true
        shift
        ;;
      --dev|--staging)
        EXPLICIT_ENV='staging'
        EXPLICIT_ENV_SET=true
        shift
        ;;
      --release)
        EXPLICIT_ACTION='release'
        EXPLICIT_ACTION_SET=true
        shift
        ;;
      --patch)
        EXPLICIT_ACTION='patch'
        EXPLICIT_ACTION_SET=true
        shift
        ;;
      --release-version)
        if [[ $# -lt 2 ]]; then
          print_error "❌ Missing value for $1"
          exit 1
        fi
        EXPLICIT_RELEASE_VERSION="$2"
        EXPLICIT_RELEASE_VERSION_SET=true
        shift 2
        ;;
      --staging-release)
        PRESET_ENV='staging'
        PRESET_ENV_SET=true
        PRESET_ACTION='release'
        PRESET_ACTION_SET=true
        shift
        ;;
      --prod-release)
        PRESET_ENV='prod'
        PRESET_ENV_SET=true
        PRESET_ACTION='release'
        PRESET_ACTION_SET=true
        shift
        ;;
      --staging-patch)
        PRESET_ENV='staging'
        PRESET_ENV_SET=true
        PRESET_ACTION='patch'
        PRESET_ACTION_SET=true
        shift
        ;;
      --prod-patch)
        PRESET_ENV='prod'
        PRESET_ENV_SET=true
        PRESET_ACTION='patch'
        PRESET_ACTION_SET=true
        shift
        ;;
      --with-creds|--decrypt)
        EXPLICIT_DECRYPT='true'
        EXPLICIT_DECRYPT_SET=true
        shift
        ;;
      --no-decrypt)
        EXPLICIT_DECRYPT='false'
        EXPLICIT_DECRYPT_SET=true
        shift
        ;;
      --quick)
        QUICK_MODE=true
        INTERACTIVE=false
        PRESET_ENV='staging'
        PRESET_ENV_SET=true
        PRESET_ACTION='release'
        PRESET_ACTION_SET=true
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
      *)
        print_error "❌ Unknown option: $1"
        echo ''
        usage
        exit 1
        ;;
    esac
  done
}

resolve_config() {
  # Environment
  if [[ "$EXPLICIT_ENV_SET" == "true" ]]; then
    ENVIRONMENT="$EXPLICIT_ENV"
    ENVIRONMENT_SOURCE='explicit'
  elif [[ "$PRESET_ENV_SET" == "true" ]]; then
    ENVIRONMENT="$PRESET_ENV"
    ENVIRONMENT_SOURCE='preset'
  elif [[ -n "$ENVIRONMENT" ]]; then
    ENVIRONMENT="$(normalize_environment "$ENVIRONMENT")"
    ENVIRONMENT_SOURCE='env'
  elif [[ "$SAVED_ENV_SET" == "true" ]]; then
    ENVIRONMENT="$SAVED_ENV"
    ENVIRONMENT_SOURCE='saved'
  else
    ENVIRONMENT='staging'
    ENVIRONMENT_SOURCE='default'
  fi

  if ! is_valid_environment "$ENVIRONMENT"; then
    print_error "❌ Invalid environment: $ENVIRONMENT (expected staging|prod)"
    exit 1
  fi

  # Action
  if [[ "$EXPLICIT_ACTION_SET" == "true" ]]; then
    SHOREBIRD_ACTION="$EXPLICIT_ACTION"
    ACTION_SOURCE='explicit'
  elif [[ "$PRESET_ACTION_SET" == "true" ]]; then
    SHOREBIRD_ACTION="$PRESET_ACTION"
    ACTION_SOURCE='preset'
  elif [[ -n "$SHOREBIRD_ACTION" ]]; then
    ACTION_SOURCE='env'
  elif [[ "$SAVED_ACTION_SET" == "true" ]]; then
    SHOREBIRD_ACTION="$SAVED_ACTION"
    ACTION_SOURCE='saved'
  else
    SHOREBIRD_ACTION='release'
    ACTION_SOURCE='default'
  fi

  if ! is_valid_action "$SHOREBIRD_ACTION"; then
    print_error "❌ Invalid SHOREBIRD_ACTION: $SHOREBIRD_ACTION (expected release|patch)"
    exit 1
  fi

  # Credentials
  if [[ "$EXPLICIT_DECRYPT_SET" == "true" ]]; then
    DECRYPT_CREDENTIALS="$EXPLICIT_DECRYPT"
    DECRYPT_SOURCE='explicit'
  elif [[ "$PRESET_DECRYPT_SET" == "true" ]]; then
    DECRYPT_CREDENTIALS="$PRESET_DECRYPT"
    DECRYPT_SOURCE='preset'
  elif [[ -n "$DECRYPT_CREDENTIALS" ]]; then
    DECRYPT_SOURCE='env'
  elif [[ "$SAVED_DECRYPT_SET" == "true" ]]; then
    DECRYPT_CREDENTIALS="$SAVED_DECRYPT"
    DECRYPT_SOURCE='saved'
  else
    DECRYPT_CREDENTIALS='true'
    DECRYPT_SOURCE='default'
  fi

  if ! is_bool "$DECRYPT_CREDENTIALS"; then
    print_error "❌ Invalid DECRYPT_CREDENTIALS value: $DECRYPT_CREDENTIALS (expected true|false)"
    exit 1
  fi

  # Release version (optional, patch only)
  if [[ "$EXPLICIT_RELEASE_VERSION_SET" == "true" ]]; then
    RELEASE_VERSION="$EXPLICIT_RELEASE_VERSION"
    RELEASE_VERSION_SOURCE='explicit'
  elif [[ -n "$RELEASE_VERSION" ]]; then
    RELEASE_VERSION_SOURCE='env'
  elif [[ "$SAVED_RELEASE_VERSION_SET" == "true" ]]; then
    RELEASE_VERSION="$SAVED_RELEASE_VERSION"
    RELEASE_VERSION_SOURCE='saved'
  else
    RELEASE_VERSION=''
    RELEASE_VERSION_SOURCE='default'
  fi
}

select_action() {
  print_header
  echo -e "${BLUE}🔁 Shorebird Action Selection (step 1/2):${NC}"
  echo '  1) Release'
  echo '  2) Patch'
  echo ''
  echo '  0) Exit'
  echo ''
  read -r -p 'Select an option: ' action_choice

  case "$action_choice" in
    1)
      SHOREBIRD_ACTION='release'
      print_step '✅ Selected: Release'
      ;;
    2)
      SHOREBIRD_ACTION='patch'
      print_step '✅ Selected: Patch'
      ;;
    0)
      print_info '👋 Goodbye!'
      exit 0
      ;;
    *)
      print_error '❌ Invalid option. Please try again.'
      select_action
      return
      ;;
  esac
}

select_environment() {
  echo ''
  print_header
  echo -e "${BLUE}║              Environment Selection (step 2/2)             ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ''
  echo '  1) Staging (staging) - Default'
  echo '  2) Production (prod)'
  echo '  0) Back'
  echo ''
  read -r -p 'Select environment: ' env_choice

  case "$env_choice" in
    1)
      ENVIRONMENT='staging'
      print_step '✅ Selected: Staging (staging)'
      ;;
    2)
      ENVIRONMENT='prod'
      print_step '✅ Selected: Production (prod)'
      ;;
    0)
      select_action
      select_environment
      return
      ;;
    *)
      print_error '❌ Invalid option. Please try again.'
      select_environment
      return
      ;;
  esac
}

show_summary() {
  echo ''
  print_header
  echo -e "${BLUE}║                    Configuration Summary                   ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ''
  echo -e "${BLUE}📱 Platform:${NC} Android"
  echo -e "${BLUE}🔁 Action:${NC} $SHOREBIRD_ACTION"
  echo -e "${BLUE}🔧 Environment:${NC} $ENVIRONMENT"
  echo -e "${BLUE}🔐 Credentials:${NC} $DECRYPT_CREDENTIALS"
  if [[ "$SHOREBIRD_ACTION" == 'patch' && -n "$RELEASE_VERSION" ]]; then
    echo -e "${BLUE}🏷️ Release version:${NC} $RELEASE_VERSION"
  fi
  echo ''
  echo '  1) Start'
  echo '  2) Change Configuration'
  echo '  0) Exit'
  echo ''
  read -r -p 'Select an option: ' confirm_choice

  case "$confirm_choice" in
    1)
      ;;
    2)
      select_action
      select_environment
      show_summary
      return
      ;;
    0)
      print_info '👋 Goodbye!'
      exit 0
      ;;
    *)
      print_error '❌ Invalid option. Please try again.'
      show_summary
      return
      ;;
  esac
}

parse_args "$@"
load_saved_state
resolve_config

if [[ "$INTERACTIVE" == "true" ]]; then
  select_action
  select_environment
  ENVIRONMENT_SOURCE='interactive'
  ACTION_SOURCE='interactive'
  show_summary
fi

if [[ "$SHOREBIRD_ACTION" != 'patch' && "$EXPLICIT_RELEASE_VERSION_SET" == 'true' ]]; then
  print_info '⚠️  --release-version is only used with --patch and will be ignored.'
fi

cd "$REPO_ROOT"

echo ''
print_step "🚀 Starting Shorebird $SHOREBIRD_ACTION for Trovara Android ($ENVIRONMENT environment)..."

if [[ "$ENVIRONMENT_SOURCE" == 'saved' || "$ACTION_SOURCE" == 'saved' || "$DECRYPT_SOURCE" == 'saved' || "$RELEASE_VERSION_SOURCE" == 'saved' ]]; then
  print_info '↺ Reusing last saved Shorebird configuration'
fi

if [[ "$QUICK_MODE" == "true" ]]; then
  print_info '⚡ Quick preset enabled'
fi

if ! command -v shorebird >/dev/null 2>&1; then
  print_error '❌ Shorebird CLI is not installed or not in PATH.'
  print_info '💡 Install: https://docs.shorebird.dev/code-push/cli/'
  exit 1
fi

if [[ "$DECRYPT_CREDENTIALS" == 'true' ]]; then
  if [[ ! -f "$SCRIPT_DIR/keystore.sh" ]]; then
    print_error "❌ Keystore script not found: $SCRIPT_DIR/keystore.sh"
    exit 1
  fi

  print_step "🔐 Preparing Android credentials for $ENVIRONMENT..."
  "$SCRIPT_DIR/keystore.sh" --env "$ENVIRONMENT"
fi

CONFIG_FILE="$REPO_ROOT/configs/trovara_${ENVIRONMENT}.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  print_error "❌ Configuration file not found: $CONFIG_FILE"
  exit 1
fi

ENTRY_POINT="$REPO_ROOT/lib/main_${ENVIRONMENT}.dart"
if [[ ! -f "$ENTRY_POINT" ]]; then
  print_error "❌ Entry point not found: $ENTRY_POINT"
  exit 1
fi

print_step "📋 Using config: $CONFIG_FILE"

SHOREBIRD_CMD=(shorebird "$SHOREBIRD_ACTION" android
  "--flavor=$ENVIRONMENT"
  "--target=$ENTRY_POINT"
  "--dart-define-from-file=$CONFIG_FILE")

if [[ "$SHOREBIRD_ACTION" == 'patch' && -n "$RELEASE_VERSION" ]]; then
  SHOREBIRD_CMD+=("--release-version=$RELEASE_VERSION")
fi

save_run_state

echo ''
print_step '🔧 Command:'
printf '   %q ' "${SHOREBIRD_CMD[@]}"
echo ''
echo ''

if [[ "$DRY_RUN" == 'true' ]]; then
  print_info 'ℹ️  Dry run complete. Command not executed.'
  exit 0
fi

exec "${SHOREBIRD_CMD[@]}"
