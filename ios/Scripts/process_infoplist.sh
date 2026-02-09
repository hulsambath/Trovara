#!/bin/bash

# This script processes Info.plist and replaces dart-define placeholders with actual values
# Run this as a "Run Script" build phase AFTER "Process dart-defines"

set -e

INFO_PLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"
DART_DEFINES_FILE="${SRCROOT}/Flutter/DartDefines.xcconfig"

echo "Processing Info.plist with dart-defines..."
echo "Info.plist: $INFO_PLIST"
echo "DartDefines: $DART_DEFINES_FILE"

# Run process_dart_defines.sh to ensure config is up to date
echo "Decoding dart-defines..."
"${SRCROOT}/Scripts/process_dart_defines.sh"

# Check if DartDefines file exists
if [ ! -f "$DART_DEFINES_FILE" ]; then
    echo "Warning: DartDefines.xcconfig not found. Skipping Info.plist processing."
    exit 0
fi

# Read dart-defines and replace placeholders in Info.plist
while IFS='=' read -r key value; do
    # Skip empty lines and comments
    [[ -z "$key" || "$key" =~ ^#  ]] && continue

    # Replace $(KEY) with actual value in Info.plist
    /usr/libexec/PlistBuddy -c "Set :GIDClientID $value" "$INFO_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $value" "$INFO_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $value" "$INFO_PLIST" 2>/dev/null || true

    # Replace URL scheme
    /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $value" "$INFO_PLIST" 2>/dev/null || true

done < "$DART_DEFINES_FILE"

# Specifically handle the keys we need
IOS_GOOGLE_CLIENT_ID=$(grep "^IOS_GOOGLE_CLIENT_ID=" "$DART_DEFINES_FILE" | cut -d'=' -f2-)
IOS_GOOGLE_REVERSED_CLIENT_ID=$(grep "^IOS_GOOGLE_REVERSED_CLIENT_ID=" "$DART_DEFINES_FILE" | cut -d'=' -f2-)
APP_NAME=$(grep "^APP_NAME=" "$DART_DEFINES_FILE" | cut -d'=' -f2-)
APP_SCHEME=$(grep "^APP_SCHEME=" "$DART_DEFINES_FILE" | cut -d'=' -f2-)

if [ -n "$IOS_GOOGLE_CLIENT_ID" ]; then
    /usr/libexec/PlistBuddy -c "Set :GIDClientID $IOS_GOOGLE_CLIENT_ID" "$INFO_PLIST"
    echo "Set GIDClientID to: $IOS_GOOGLE_CLIENT_ID"
fi

if [ -n "$IOS_GOOGLE_REVERSED_CLIENT_ID" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $IOS_GOOGLE_REVERSED_CLIENT_ID" "$INFO_PLIST"
    echo "Set URL scheme to: $IOS_GOOGLE_REVERSED_CLIENT_ID"
fi

if [ -n "$APP_NAME" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$INFO_PLIST"
    echo "Set CFBundleDisplayName to: $APP_NAME"
fi

if [ -n "$APP_SCHEME" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_SCHEME" "$INFO_PLIST"
    echo "Set CFBundleName to: $APP_SCHEME"
fi

echo "Info.plist processing complete!"
