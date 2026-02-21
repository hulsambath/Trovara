plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.Project

// Function to determine credentials directory based on flavor
fun Project.getCredentialsDir(flavorName: String?): String {
    val flavor = flavorName ?: "dev"
    val credentialsBase = rootProject.file("../../credentials/android/trovara")
    return when (flavor) {
        "prod", "production", "release" -> credentialsBase.absolutePath + "/prod"
        else -> credentialsBase.absolutePath + "/dev"
    }
}

// Function to load keystore properties from credentials project
fun Project.loadKeystoreFromCredentials(flavorName: String): Properties {
    val credentialsDir = getCredentialsDir(flavorName)
    val keystoreProps = Properties()

    // Try to load from decrypted keystore.properties in credentials directory
    val keystorePropsFile = file(credentialsDir + "/keystore.properties")
    if (keystorePropsFile.exists()) {
        println("🔐 Loading keystore properties from: " + keystorePropsFile.absolutePath)
        FileInputStream(keystorePropsFile).use { fis -> keystoreProps.load(fis) }
    } else {
        println("⚠️  Keystore properties not found at: " + keystorePropsFile.absolutePath)
        println("💡 Run: cd ../../credentials && ./scripts/generate-keystore.sh --project trovara --env " + flavorName)
    }

    return keystoreProps
}

// Load keystore properties from credentials project
val keystoreProps = project.loadKeystoreFromCredentials("prod")

// Get the credentials directory based on flavor
val flavorName = "prod"
val credentialsDir = project.getCredentialsDir(flavorName)

val storeFileProp = if (keystoreProps.getProperty("storeFile") != null) {
    credentialsDir + "/" + keystoreProps.getProperty("storeFile")
} else {
    project.findProperty("KEYSTORE_FILE") as String?
}

val storePasswordProp = (keystoreProps.getProperty("storePassword")
    ?: (project.findProperty("KEYSTORE_PASSWORD") as String?))
val keyAliasProp = (keystoreProps.getProperty("keyAlias")
    ?: (project.findProperty("KEY_ALIAS") as String?))
val keyPasswordProp = (keystoreProps.getProperty("keyPassword")
    ?: (project.findProperty("KEY_PASSWORD") as String?))
val hasKeystore = listOf(storeFileProp, storePasswordProp, keyAliasProp, keyPasswordProp).all { it != null }

android {
    namespace = "com.trovara.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13599879"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.trovara.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        create("prod") {
            applicationIdSuffix = ""
            versionNameSuffix = ""
        }
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
        }
    }

    // Print debug info about keystore loading
    if (hasKeystore) {
        println("🔐 Using keystore from: " + storeFileProp)
        println("🔑 Key alias: " + keyAliasProp)
        println("📁 Credentials directory: " + credentialsDir)
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystore) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
        debug {
            signingConfig = if (hasKeystore) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
