# Google Sign-In Error (Code 10) - Fix Guide

## Problem
The app is experiencing error code 10 (DEVELOPER_ERROR) when attempting Google Sign-In:
```
PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10:, null, null)
```

## Root Cause
**Missing `google-services.json` file** - This configuration file is required for Google Play Services integration on Android and is generated from Firebase/Google Cloud Console.

## Solution: Step-by-Step Fix

### 1. Get Your Debug SHA-1 Fingerprint
Run this command from the noteminds root directory:

```bash
cd /home/sambath/Documents/project/noteminds/android
./gradlew signingReport
```

This will output something like:
```
Variant: debugAndroidTest
Config: debug
Store: /path/to/.android/debug.keystore
Alias: AndroidDebugKey
MD5: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
SHA256: ...
```

**Copy the SHA1 value** - you'll need this in the next step.

### 2. Setup Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing one
3. Enable these APIs:
   - Google Drive API
   - Google Sign-In API
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client IDs"
5. Select "Android" application type
6. Fill in:
   - **Package name**: `com.notemyminds.app.dev` (for debug builds)
   - **SHA-1 certificate fingerprint**: Paste the SHA1 from step 1

### 3. Download google-services.json
1. After creating the OAuth client, download the `google-services.json` file from Google Cloud Console
2. Place it in: `/home/sambath/Documents/project/noteminds/android/app/google-services.json`

### 4. Add Firebase/Google Services Plugin
Update `/home/sambath/Documents/project/noteminds/android/build.gradle.kts`:

```gradle
plugins {
    id("com.google.gms.google-services") version "4.3.15" apply false
}
```

Update `/home/sambath/Documents/project/noteminds/android/app/build.gradle.kts`:

Add at the bottom (after `flutter` block):
```gradle
apply plugin: 'com.google.gms.google-services'
```

### 5. Verify AndroidManifest Permissions
Check `/home/sambath/Documents/project/noteminds/android/app/src/main/AndroidManifest.xml` includes:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### 6. Clean and Rebuild
```bash
cd /home/sambath/Documents/project/noteminds/android
./gradlew clean
./gradlew flutter:clean
flutter clean
flutter pub get
flutter run
```

## Alternative: Quick Workaround
If you need to test without Google Sign-In temporarily:
1. In `lib/core/services/google_drive_service.dart`, add try-catch for testing
2. Disable Google Sign-In in the UI temporarily

## Troubleshooting
| Error | Solution |
|-------|----------|
| API key not valid for this package name | SHA-1 fingerprint mismatch - regenerate using `gradlew signingReport` |
| 10: DEVELOPER_ERROR | Missing or misconfigured google-services.json |
| Service unavailable | Google Play Services not installed on test device |

## For Production (prod flavor)
When building with production flavor:
1. Get SHA-1 from your production keystore
2. Create another OAuth client with `com.notemyminds.app` package name
3. Download corresponding google-services.json for prod flavor

---
Created: 2025-12-21
