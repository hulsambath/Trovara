plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// Load keystore properties from android/key.properties (preferred) or Gradle properties
val keystoreProps = Properties()
val keyPropsFile = rootProject.file("android/key.properties")
if (keyPropsFile.exists()) {
    FileInputStream(keyPropsFile).use { fis -> keystoreProps.load(fis) }
}

val storeFileProp = (keystoreProps.getProperty("storeFile")
    ?: (project.findProperty("KEYSTORE_FILE") as String?))
val storePasswordProp = (keystoreProps.getProperty("storePassword")
    ?: (project.findProperty("KEYSTORE_PASSWORD") as String?))
val keyAliasProp = (keystoreProps.getProperty("keyAlias")
    ?: (project.findProperty("KEY_ALIAS") as String?))
val keyPasswordProp = (keystoreProps.getProperty("keyPassword")
    ?: (project.findProperty("KEY_PASSWORD") as String?))
val hasKeystore = listOf(storeFileProp, storePasswordProp, keyAliasProp, keyPasswordProp).all { it != null }

android {
    namespace = "com.noteminds.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13599879"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.noteminds.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only create a custom release signing config when keystore is fully provided
        if (hasKeystore) {
            create("release") {
                storeFile = file(storeFileProp!!)
                storePassword = storePasswordProp!!
                keyAlias = keyAliasProp!!
                keyPassword = keyPasswordProp!!
            }
            create("debug") {
                storeFile = file(storeFileProp!!)
                storePassword = storePasswordProp!!
                keyAlias = keyAliasProp!!
                keyPassword = keyPasswordProp!!
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystore) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
