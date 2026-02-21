#!/usr/bin/env bash
set -euo pipefail

# Script to get SHA-1 fingerprints for Google Sign-In configuration
# Usage: ./scripts/get_sha1.sh [--env dev|prod]

ENVIRONMENT="${1:-prod}"
CREDENTIALS_DIR="../credentials/android/trovara/${ENVIRONMENT}"

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

