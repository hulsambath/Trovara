#!/usr/bin/env bash
set -euo pipefail

# Get SHA-1 fingerprints for Google Sign-In configuration
#
# Usage:
#   ./scripts/get_sha1.sh                       # Get both debug and release SHA-1
#   ./scripts/get_sha1.sh --env staging         # Get SHA-1 for staging environment
#   ./scripts/get_sha1.sh --env prod            # Get SHA-1 for production environment
#   ./scripts/get_sha1.sh --help                # Show help

ENVIRONMENT="${1:-prod}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENVIRONMENT="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--env staging|prod|--help]"
      echo ""
      echo "Get SHA-1 fingerprints for Google Sign-In configuration"
      echo ""
      echo "Options:"
      echo "  --env staging   Get fingerprints for staging environment (default: prod)"
      echo "  --env prod      Get fingerprints for production environment"
      echo "  --help          Show this help"
      echo ""
      echo "Examples:"
      echo "  $0              # Get production fingerprints"
      echo "  $0 --env staging    # Get staging fingerprints"
      echo ""
      echo "Next steps after getting SHA-1:"
      echo "1. Copy the SHA-1 fingerprints above"
      echo "2. Go to Firebase Console → Project Settings → Your apps → Android app"
      echo "3. Add both SHA-1 fingerprints"
      echo "4. Download google-services.json and place it in android/app/"
      echo "5. Ensure OAuth client ID is configured for package: com.trovara.app"
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo "🔍 Getting SHA-1 fingerprints for ${ENVIRONMENT} environment..."
echo ""

# Get debug keystore SHA-1
echo "📱 Debug Keystore SHA-1:"
DEBUG_SHA1=$(keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep "SHA1:" | sed 's/.*SHA1: //' | tr -d ' ')
if [ -n "${DEBUG_SHA1}" ]; then
    echo "   ${DEBUG_SHA1}"
    echo ""
else
    echo "   ⚠️  Debug keystore not found"
    echo ""
fi

# Get release keystore SHA-1 if available
if [ -f "${CREDENTIALS_DIR}/upload.jks" ]; then
    echo "🔐 Release Keystore SHA-1:"
    
    # Try to read from keystore.properties
    if [ -f "${CREDENTIALS_DIR}/keystore.properties" ]; then
        source <(grep -E "^storePassword=|^keyPassword=|^keyAlias=" "${CREDENTIALS_DIR}/keystore.properties" | sed 's/^/export /')
        KEY_ALIAS="${keyAlias:-upload}"
        STORE_PASS="${storePassword:-}"
        KEY_PASS="${keyPassword:-${STORE_PASS}}"
        
        if [ -n "${STORE_PASS}" ]; then
            RELEASE_SHA1=$(keytool -list -v -keystore "${CREDENTIALS_DIR}/upload.jks" \
                -alias "${KEY_ALIAS}" \
                -storepass "${STORE_PASS}" \
                -keypass "${KEY_PASS}" 2>/dev/null | grep "SHA1:" | sed 's/.*SHA1: //' | tr -d ' ')
            if [ -n "${RELEASE_SHA1}" ]; then
                echo "   ${RELEASE_SHA1}"
                echo ""
            else
                echo "   ⚠️  Could not read keystore (check password)"
                echo ""
            fi
        else
            echo "   ⚠️  Store password not found in keystore.properties"
            echo "   💡 Run manually:"
            echo "      keytool -list -v -keystore ${CREDENTIALS_DIR}/upload.jks -alias <alias>"
            echo ""
        fi
    else
        echo "   ⚠️  keystore.properties not found"
        echo "   💡 Run manually:"
        echo "      keytool -list -v -keystore ${CREDENTIALS_DIR}/upload.jks -alias <alias>"
        echo ""
    fi
else
    echo "⚠️  Release keystore not found at: ${CREDENTIALS_DIR}/upload.jks"
    echo ""
fi

echo "📋 Next steps:"
echo "1. Copy the SHA-1 fingerprints above"
echo "2. Go to Firebase Console → Project Settings → Your apps → Android app"
echo "3. Add both SHA-1 fingerprints"
echo "4. Download google-services.json and place it in android/app/"
echo "5. Ensure OAuth client ID is configured for package: com.trovara.app"

