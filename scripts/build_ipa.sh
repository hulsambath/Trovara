#!/usr/bin/env bash
set -euo pipefail

# Flutter iOS IPA builder (Xcode / signing on this Mac)
#
# Does not use Android keystores. Use the same dart-define + flavor + entrypoint
# as build_apk.sh / build_appbundle.sh.
#
# Usage:
#   ./scripts/build_ipa.sh                  # staging
#   ./scripts/build_ipa.sh --prod           # prod
#   ./scripts/build_ipa.sh -- --export-options-plist=ios/ExportOptions.plist
#
# Extra arguments after -- are passed to flutter build ipa.

ENVIRONMENT="staging"
PASS_THROUGH=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --)
      shift
      PASS_THROUGH+=("$@")
      break
      ;;
    -nm|--trovara)
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
    --help)
      echo "Usage: $0 [-nm|--trovara] [--prod|--dev] [-- <extra flutter build ipa args>]"
      echo ""
      echo "Build a release IPA with Trovara staging or prod flavor."
      echo "Configure signing & export in Xcode or via --export-options-plist (after --)."
      echo ""
      echo "Options:"
      echo "  -nm, --trovara   Trovara project (default)"
      echo "  --prod           Production flavor"
      echo "  --dev            Staging flavor (alias)"
      echo "  --help           Show this help"
      echo ""
      echo "Examples:"
      echo "  $0"
      echo "  $0 --prod"
      echo "  $0 --prod -- --export-options-plist=ios/ExportOptions.plist"
      echo ""
      echo "Output:"
      echo "  build/ios/ipa/*.ipa"
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

echo "🍎 Building Trovara IPA ($ENVIRONMENT environment)..."

CONFIG_FILE="configs/trovara_${ENVIRONMENT}.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Configuration file not found: $CONFIG_FILE"
  exit 1
fi

echo "📋 Using config: $CONFIG_FILE"

FLUTTER_CMD=(flutter build ipa
  --dart-define-from-file="$CONFIG_FILE"
  --release)

if [[ "$ENVIRONMENT" == "prod" ]]; then
  FLUTTER_CMD+=(--flavor prod --target=lib/main_prod.dart)
else
  FLUTTER_CMD+=(--flavor staging --target=lib/main_staging.dart)
fi

if [[ ${#PASS_THROUGH[@]} -gt 0 ]]; then
  FLUTTER_CMD+=("${PASS_THROUGH[@]}")
fi

echo "🔨 Building IPA..."
printf '🔧 '; printf '%q ' "${FLUTTER_CMD[@]}"; echo; echo

"${FLUTTER_CMD[@]}"

echo ""
echo "✅ IPA build completed!"
echo "📁 build/ios/ipa/"
