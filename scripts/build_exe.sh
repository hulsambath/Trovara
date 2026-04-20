#!/usr/bin/env bash
set -euo pipefail

# Flutter Windows EXE builder
#
# Usage:
#   ./scripts/build_exe.sh                  # Build Windows EXE
#
# Quicker via CLI hub:
#   dev build exe                           # Build Windows EXE

# Function to convert JSON file to --dart-define flags
json_to_dart_define() {
  local CONFIG_FILE=$1
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
  fi

  # Using jq to convert JSON to --dart-define=KEY=VALUE
  jq -r 'to_entries | map("--dart-define=\(.key)=\(.value|tostring)") | .[]' "$CONFIG_FILE"
}

case "${1:-}" in
  -nm|--trovara)
    CONFIG_FILE="configs/trovara.json"
    DEFINE_FLAGS=$(json_to_dart_define "$CONFIG_FILE")
    CMD="flutter build windows $DEFINE_FLAGS"
    ;;
  --help|-h)
    echo "Usage: $0 [--trovara]"
    echo ""
    echo "Build Windows EXE for Trovara"
    echo ""
    echo "Options:"
    echo "  --trovara  Build Trovara (default)"
    echo "  --help     Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                  # Build Windows EXE"
    echo ""
    echo "Quicker via CLI hub:"
    echo "  dev build exe       # Build Windows EXE"
    echo ""
    echo "Output:"
    echo "  build/windows/runner/Release/"
    exit 0
    ;;
  *)
    echo "❌ Invalid option: ${1:-default}"
    echo "Usage: $0 [--trovara]"
    echo "Use --help for more information"
    exit 1
    ;;
esac

# Remove first argument
shift || true

echo "🔨 Building Windows EXE..."
echo "🔧 Command: $CMD $@"
echo ""

eval $CMD "$@"

echo ""
echo "✅ Windows EXE built successfully!"
echo "📁 Output: build/windows/runner/Release/"
