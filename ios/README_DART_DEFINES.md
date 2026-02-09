# iOS Dart-Defines Setup

## What was done

1. ✅ Created `ios/Scripts/process_dart_defines.sh` - Script to decode DART_DEFINES
2. ✅ Created `ios/Scripts/process_infoplist.sh` - Script to replace Info.plist placeholders
3. ✅ Updated `ios/Flutter/Debug.xcconfig` - Added include for DartDefines.xcconfig
4. ✅ Updated `ios/Flutter/Release.xcconfig` - Added include for DartDefines.xcconfig
5. ✅ Generated `ios/Flutter/DartDefines.xcconfig` - Contains decoded dart-define variables
6. ✅ Updated `ios/Runner/Info.plist` - Uses PLACEHOLDER values that get replaced at build time
7. ✅ Added DartDefines.xcconfig to .gitignore

## How it works

The build process now works in two stages:

### Stage 1: Decode dart-defines (automatic)

1. Flutter generates `Generated.xcconfig` with base64-encoded DART_DEFINES
2. The script `process_dart_defines.sh` decodes them to `DartDefines.xcconfig`
3. The xcconfig files include DartDefines.xcconfig

### Stage 2: Process Info.plist (needs Xcode build phase)

1. After the app is built, `process_infoplist.sh` runs
2. It reads values from `DartDefines.xcconfig`
3. It replaces PLACEHOLDER values in the built Info.plist with actual values

## Required: Add Build Phase to Xcode (Automated)

The build phase has been added automatically by the `ios/Scripts/add_build_phase.rb` script.

This script adds a "Process Info.plist with Dart Defines" build phase that runs:

```bash
"${SRCROOT}/Scripts/process_infoplist.sh"
```

This script now also handles decoding the dart-defines first, ensuring everything is up to date.

## Manual Setup (If needed)

If the automated script fails, you can add the build phase manually:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the "Runner" project in the navigator
3. Select the "Runner" target
4. Go to "Build Phases" tab
5. Click "+" and select "New Run Script Phase"
6. Drag it to run AFTER "Thin Binary" phase
7. Name it: "Process Info.plist with Dart Defines"
8. Add this script:

```bash
"${SRCROOT}/Scripts/process_infoplist.sh"
```

9. Uncheck "Based on dependency analysis"

## Variables now available in Info.plist

After the build script runs, these placeholders are replaced:

- `PLACEHOLDER_APP_NAME` → Value from `APP_NAME`
- `PLACEHOLDER_APP_SCHEME` → Value from `APP_SCHEME`
- `PLACEHOLDER_IOS_GOOGLE_CLIENT_ID` → Value from `IOS_GOOGLE_CLIENT_ID`
- `PLACEHOLDER_IOS_GOOGLE_REVERSED_CLIENT_ID` → Value from `IOS_GOOGLE_REVERSED_CLIENT_ID`

## Testing

Run the app with:

```bash
./scripts/run_app.sh ios
```

The Info.plist in the built app will have the actual values from your `configs/notemyminds_prod.json` file!

## Note

- The `DartDefines.xcconfig` file is auto-generated and should not be committed to git (already in .gitignore)
- The Info.plist in the source has PLACEHOLDER values - the actual values are only in the built app
- This ensures Google Sign-In works correctly with the proper client ID
