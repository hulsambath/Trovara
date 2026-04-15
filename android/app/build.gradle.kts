plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException
import org.gradle.api.Project

// Function to determine credentials directory based on flavor
fun Project.getCredentialsDir(flavorName: String?): String {
    val flavor = flavorName ?: "staging"
    val credentialsBase = rootProject.file("../../credentials/android/trovara")
    return when (flavor) {
        "prod", "production", "release" -> credentialsBase.absolutePath + "/prod"
        else -> credentialsBase.absolutePath + "/staging"
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

// Helper to resolve signing properties for a given flavor
data class SigningProps(
    val storeFile: String?,
    val storePassword: String?,
    val keyAlias: String?,
    val keyPassword: String?,
    val credentialsDir: String,
) {
    val isComplete get() = listOf(storeFile, storePassword, keyAlias, keyPassword).all { it != null }
}

fun Project.resolveSigningProps(flavor: String): SigningProps {
    val props = loadKeystoreFromCredentials(flavor)
    val dir = getCredentialsDir(flavor)

    val storeFile = if (props.getProperty("storeFile") != null) {
        dir + "/" + props.getProperty("storeFile")
    } else {
        findProperty("KEYSTORE_FILE") as String?
    }

    return SigningProps(
        storeFile = storeFile,
        storePassword = props.getProperty("storePassword") ?: (findProperty("KEYSTORE_PASSWORD") as String?),
        keyAlias = props.getProperty("keyAlias") ?: (findProperty("KEY_ALIAS") as String?),
        keyPassword = props.getProperty("keyPassword") ?: (findProperty("KEY_PASSWORD") as String?),
        credentialsDir = dir,
    )
}

val stagingSigning = project.resolveSigningProps("staging")
val prodSigning = project.resolveSigningProps("prod")

android {
    namespace = "com.trovara.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13599879"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
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

    signingConfigs {
        if (stagingSigning.isComplete) {
            create("stagingRelease") {
                storeFile = file(stagingSigning.storeFile!!)
                storePassword = stagingSigning.storePassword!!
                keyAlias = stagingSigning.keyAlias!!
                keyPassword = stagingSigning.keyPassword!!
            }
            println("🔐 Staging keystore: ${stagingSigning.storeFile}")
            println("🔑 Staging key alias: ${stagingSigning.keyAlias}")
            println("📁 Staging credentials: ${stagingSigning.credentialsDir}")
        }
        if (prodSigning.isComplete) {
            create("prodRelease") {
                storeFile = file(prodSigning.storeFile!!)
                storePassword = prodSigning.storePassword!!
                keyAlias = prodSigning.keyAlias!!
                keyPassword = prodSigning.keyPassword!!
            }
            println("🔐 Prod keystore: ${prodSigning.storeFile}")
            println("🔑 Prod key alias: ${prodSigning.keyAlias}")
            println("📁 Prod credentials: ${prodSigning.credentialsDir}")
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("staging") {
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            if (stagingSigning.isComplete) {
                signingConfig = signingConfigs.getByName("stagingRelease")
            }
        }
        create("prod") {
            applicationIdSuffix = ""
            versionNameSuffix = ""
            if (prodSigning.isComplete) {
                signingConfig = signingConfigs.getByName("prodRelease")
            }
        }
    }

    buildTypes {
        release {
            // Signing is set per product flavor (stagingRelease / prodRelease only). Do not fall back
            // to the other flavor’s key here — that would sign `prod` builds with the staging keystore.
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Fail fast if `prod` release is built without prod credentials (avoids silently using staging key).
gradle.taskGraph.whenReady {
    if (prodSigning.isComplete) return@whenReady
    val prodReleaseArtifacts = setOf("bundleProdRelease", "assembleProdRelease")
    if (allTasks.any { it.name in prodReleaseArtifacts }) {
        throw GradleException(
            "Prod flavor requires prod signing. Add credentials at " +
                "${project.getCredentialsDir("prod")}/keystore.properties " +
                "(run: cd ../../credentials && ./scripts/generate-keystore.sh --project trovara --env prod).",
        )
    }
}
