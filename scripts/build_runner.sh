#!/usr/bin/env bash
set -euo pipefail

# Flutter build_runner - Generate ObjectBox and other code
#
# Usage:
#   ./scripts/build_runner.sh                   # Run build_runner (default)
#   ./scripts/build_runner.sh -d                # Delete conflicting outputs first
#   ./scripts/build_runner.sh --help            # Show help
#
# Quicker via CLI hub:
#   dev setup build-runner                      # Run build_runner

echo "🔨 Running Flutter build_runner..."
echo ""

case "${1:-}" in
  -d|--delete-conflicting-outputs)
    echo "📋 Deleting conflicting outputs..."
    flutter pub run build_runner build -d
    ;;
  --help|-h)
    echo "Usage: $0 [-d|--delete-conflicting-outputs]"
    echo ""
    echo "Generate code for ObjectBox and other packages"
    echo ""
    echo "Options:"
    echo "  -d, --delete-conflicting-outputs  Delete conflicting outputs before building"
    echo "  --help                            Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run build_runner"
    echo "  $0 -d                 # Delete conflicts first"
    echo ""
    echo "Quicker via CLI hub:"
    echo "  dev setup build-runner"
    exit 0
    ;;
  *)
    echo "Running build_runner..."
    flutter pub run build_runner build
    ;;
esac

echo ""
echo "✅ Build runner completed!"
