import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: create android/key.properties from key.properties.example.
// Never commit key.properties or *.jks / *.keystore files.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystoreFile = keystorePropertiesFile.exists()

data class ReleaseKeystoreConfig(
    val storeFile: java.io.File,
    val storePassword: String,
    val keyAlias: String,
    val keyPassword: String,
)

fun validateReleaseKeystore(): ReleaseKeystoreConfig? {
    if (!hasReleaseKeystoreFile) {
        return null
    }

    keystoreProperties.load(FileInputStream(keystorePropertiesFile))

    val requiredKeys = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
    val missingKeys = requiredKeys.filter { key ->
        keystoreProperties.getProperty(key).isNullOrBlank()
    }
    if (missingKeys.isNotEmpty()) {
        throw GradleException(
            "Release keystore misconfigured: missing or empty key.properties entries: " +
                missingKeys.joinToString(", ") +
                ". Copy android/key.properties.example → android/key.properties. " +
                "See docs/release/ANDROID_RELEASE_CHECKLIST.md",
        )
    }

    val storeFile = file(keystoreProperties.getProperty("storeFile"))
    if (!storeFile.exists()) {
        throw GradleException(
            "Release keystore misconfigured: storeFile not found at ${storeFile.path}. " +
                "Create the upload keystore per android/key.properties.example. " +
                "See docs/release/ANDROID_RELEASE_CHECKLIST.md",
        )
    }

    return ReleaseKeystoreConfig(
        storeFile = storeFile,
        storePassword = keystoreProperties.getProperty("storePassword"),
        keyAlias = keystoreProperties.getProperty("keyAlias"),
        keyPassword = keystoreProperties.getProperty("keyPassword"),
    )
}

val releaseKeystoreConfig = validateReleaseKeystore()

android {
    namespace = "com.falcon_log.falconlog"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        if (releaseKeystoreConfig != null) {
            create("release") {
                keyAlias = releaseKeystoreConfig.keyAlias
                keyPassword = releaseKeystoreConfig.keyPassword
                storeFile = releaseKeystoreConfig.storeFile
                storePassword = releaseKeystoreConfig.storePassword
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    defaultConfig {
        // FalconLog Application ID
        applicationId = "com.falcon_log.falconlog"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            isDebuggable = true
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            if (releaseKeystoreConfig != null) {
                signingConfig = signingConfigs.getByName("release")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

gradle.taskGraph.whenReady {
    val requestedReleaseBuild = allTasks.any { task ->
        task.project == project && task.name.contains("Release", ignoreCase = true)
    }

    if (requestedReleaseBuild && releaseKeystoreConfig == null) {
        throw GradleException(
            "Release keystore is required for release builds. " +
                "Create android/key.properties from key.properties.example " +
                "and keep key.properties / keystore files out of Git. " +
                "See docs/release/ANDROID_RELEASE_CHECKLIST.md",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
