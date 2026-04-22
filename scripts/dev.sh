#!/usr/bin/env bash
set -euo pipefail

# Trovara Developer CLI Hub - Unified script interface
# Makes common development tasks fast and easy
#
# Usage:
#   dev build [apk|ipa|aab|exe] [prod|staging] [--quick]
#   dev run [--quick]
#   dev setup [all|hooks|build-runner|firebase]
#   dev creds [status|decrypt] [--env staging|prod]
#   dev help

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_header() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  🚀 Trovara Developer CLI${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_step() {
  echo -e "${GREEN}✓${NC} $1"
}

print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

print_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_section() {
  echo ""
  echo -e "${BLUE}▶ $1${NC}"
}

# Check required tool
check_tool() {
  if ! command -v "$1" &> /dev/null; then
    print_error "$1 is not installed"
    return 1
  fi
}

# Validate environment variable
validate_env() {
  case "$1" in
    prod|staging|dev)
      [[ "$1" == "dev" ]] && echo "staging" || echo "$1"
      ;;
    *)
      print_error "Invalid environment: $1"
      echo "Valid options: staging, prod"
      return 1
      ;;
  esac
}

# Validate build type
validate_build_type() {
  case "$1" in
    apk|ipa|aab|exe)
      echo "$1"
      ;;
    *)
      print_error "Invalid build type: $1"
      echo "Valid options: apk, ipa, aab, exe"
      return 1
      ;;
  esac
}

# ============================================================================
# BUILD COMMAND
# ============================================================================

cmd_build() {
  print_section "📦 Build"
  
  local build_type="${1:-apk}"
  local env="${2:-staging}"
  local quick="${3:-}"
  
  # Validate inputs
  build_type=$(validate_build_type "$build_type") || return 1
  env=$(validate_env "$env") || return 1
  
  print_info "Building: ${GREEN}$build_type${NC} (${YELLOW}$env${NC})"
  
  case "$build_type" in
    apk)
      print_step "Android APK"
      cd "$REPO_ROOT"
      if [[ "$env" == "prod" ]]; then
        ./scripts/build_apk.sh --trovara --prod
      else
        ./scripts/build_apk.sh --trovara
      fi
      echo ""
      print_step "APK built successfully!"
      print_info "📁 Output: build/app/outputs/flutter-apk/"
      ;;
    
    aab)
      print_step "Android App Bundle"
      cd "$REPO_ROOT"
      if [[ "$env" == "prod" ]]; then
        ./scripts/build_appbundle.sh --trovara --prod
      else
        ./scripts/build_appbundle.sh --trovara
      fi
      echo ""
      print_step "AAB built successfully!"
      print_info "📁 Output: build/app/outputs/bundle/${env}Release/"
      ;;
    
    ipa)
      print_step "iOS IPA"
      cd "$REPO_ROOT"
      if [[ "$env" == "prod" ]]; then
        ./scripts/build_ipa.sh --trovara --prod
      else
        ./scripts/build_ipa.sh --trovara
      fi
      echo ""
      print_step "IPA built successfully!"
      print_info "📁 Output: build/ios/ipa/"
      ;;
    
    exe)
      print_step "Windows EXE"
      cd "$REPO_ROOT"
      ./scripts/build_exe.sh --trovara
      echo ""
      print_step "EXE built successfully!"
      print_info "📁 Output: build/windows/runner/Release/"
      ;;
  esac
}

# ============================================================================
# RUN COMMAND
# ============================================================================

cmd_run() {
  print_section "🏃 Run App"
  
  local quick="${1:-}"
  
  cd "$REPO_ROOT"
  
  if [[ "$quick" == "--quick" ]]; then
    # Quick mode: staging + debug + auto-detect + no prompts
    print_info "Quick mode: using ${YELLOW}staging${NC} fast preset"
    ./scripts/run_app.sh --quick
  else
    # Keep team-familiar interactive flow from dev hub
    ./scripts/run_app.sh --interactive
  fi
}

# ============================================================================
# SETUP COMMAND
# ============================================================================

cmd_setup() {
  print_section "🔧 Setup"
  
  local target="${1:-all}"
  
  case "$target" in
    all)
      print_info "Running all setup tasks..."
      cmd_setup "hooks"
      cmd_setup "build-runner"
      cmd_setup "firebase"
      print_step "Setup complete!"
      ;;
    
    hooks)
      print_info "Installing git hooks..."
      cd "$REPO_ROOT"
      ./scripts/install_hooks.sh
      ;;
    
    build-runner)
      print_info "Running build_runner..."
      cd "$REPO_ROOT"
      ./scripts/build_runner.sh -d
      print_step "Build runner completed!"
      ;;
    
    firebase)
      print_info "Configure Firebase..."
      cd "$REPO_ROOT"
      echo ""
      echo "Choose environment:"
      echo "  1) Staging (staging)"
      echo "  2) Production (prod)"
      echo "  0) Skip"
      read -p "Select: " firebase_choice
      case "$firebase_choice" in
        1)
          ./scripts/flutterfire.sh --staging
          ;;
        2)
          ./scripts/flutterfire.sh --prod
          ;;
        0)
          print_info "Skipped Firebase setup"
          ;;
        *)
          print_error "Invalid option"
          return 1
          ;;
      esac
      ;;
    
    *)
      print_error "Unknown setup target: $target"
      echo "Valid options: all, hooks, build-runner, firebase"
      return 1
      ;;
  esac
}

# ============================================================================
# CREDS COMMAND
# ============================================================================

cmd_creds() {
  print_section "🔐 Credentials"
  
  local action="${1:-status}"
  local env="${2:-staging}"
  
  case "$action" in
    status)
      print_info "Checking credentials status..."
      cd "$REPO_ROOT"
      local staging_creds="../credentials/android/trovara/staging/upload.jks"
      local prod_creds="../credentials/android/trovara/prod/upload.jks"
      
      if [[ -f "$staging_creds" ]]; then
        print_step "Staging credentials: ${GREEN}decrypted${NC}"
      elif [[ -f "${staging_creds}.enc" ]]; then
        print_warn "Staging credentials: encrypted (run ${CYAN}dev creds decrypt staging${NC})"
      else
        print_error "Staging credentials: not found"
      fi
      
      if [[ -f "$prod_creds" ]]; then
        print_step "Production credentials: ${GREEN}decrypted${NC}"
      elif [[ -f "${prod_creds}.enc" ]]; then
        print_warn "Production credentials: encrypted (run ${CYAN}dev creds decrypt prod${NC})"
      else
        print_error "Production credentials: not found"
      fi
      ;;
    
    decrypt)
      env=$(validate_env "$env") || return 1
      print_info "Decrypting ${YELLOW}$env${NC} credentials..."
      cd "$REPO_ROOT"
      ./scripts/keystore.sh --env "$env"
      ;;
    
    *)
      print_error "Unknown creds action: $action"
      echo "Valid options: status, decrypt"
      return 1
      ;;
  esac
}

# ============================================================================
# HELP COMMAND
# ============================================================================

cmd_help() {
  cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║                     Trovara Developer CLI - Quick Reference                  ║
╚══════════════════════════════════════════════════════════════════════════════╝

BUILD COMMANDS
──────────────
  dev build apk [prod]        Build Android APK (staging by default)
  dev build aab [prod]        Build Android App Bundle
  dev build ipa [prod]        Build iOS IPA
  dev build exe               Build Windows EXE

EXAMPLES:
  dev build apk               → Build staging APK
  dev build apk prod          → Build production APK
  dev build ipa               → Build staging iOS
  dev build aab prod          → Build production AAB

RUN COMMANDS
────────────
  dev run                     Run app (interactive platform/env selection)
  dev run --quick             Run app quickly (staging + debug, no prompts)

SETUP COMMANDS
──────────────
  dev setup                   Run all setup tasks
  dev setup hooks             Install git hooks
  dev setup build-runner      Run build_runner
  dev setup firebase          Configure Firebase

CREDENTIAL COMMANDS
───────────────────
  dev creds status            Show credentials status
  dev creds decrypt [env]     Decrypt credentials (staging|prod)

EXAMPLES:
  dev creds status            → Check which credentials are decrypted
  dev creds decrypt prod      → Decrypt production credentials

SHORTCUTS & ALIASES
───────────────────
  dev build                   → dev build apk (default)
  dev build prod              → dev build apk prod
  dev run --quick             → Quick run with staging + debug

TIPS
────
• Most commands default to staging environment
• Use 'prod' flag to switch to production
• Run 'dev help' anytime to see this reference
• All output goes to standard locations (check build/ folder)

For detailed help on individual scripts:
  • ./scripts/build_apk.sh --help
  • ./scripts/run_app.sh --help
  • ./scripts/keystore.sh --help

EOF
}

# ============================================================================
# MAIN DISPATCHER
# ============================================================================

main() {
  cd "$REPO_ROOT"
  
  local command="${1:-help}"
  shift || true
  
  case "$command" in
    build)
      cmd_build "$@"
      ;;
    run)
      cmd_run "$@"
      ;;
    setup)
      cmd_setup "$@"
      ;;
    creds)
      cmd_creds "$@"
      ;;
    help)
      cmd_help
      ;;
    --help|-h)
      cmd_help
      ;;
    *)
      print_error "Unknown command: $command"
      echo ""
      cmd_help
      return 1
      ;;
  esac
}

main "$@"
