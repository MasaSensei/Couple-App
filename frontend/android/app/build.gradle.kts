import java.util.Properties

// Release signing comes from android/key.properties (git-ignored), written by
// the release lane from the secret store. Without it, release builds are
// signed with the debug key: fine for CI compile checks, rejected by Play.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseSigning = keystoreProperties.getProperty("storeFile") != null

// Final store identity is a product decision; pass -PappId=… or set it here once chosen.
val appId: String = (project.findProperty("appId") as String?) ?: "com.example.frontend"

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.frontend"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = appId

        minSdk = 26
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseSigning) "release" else "debug")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

// A store upload must never carry the placeholder id or the debug key.
gradle.taskGraph.whenReady {
    val storeBuild = allTasks.any { it.name == "bundleRelease" } && project.findProperty("storeRelease") == "true"
    if (storeBuild && (appId.startsWith("com.example") || !hasReleaseSigning)) {
        throw GradleException("Store release needs a real applicationId (-PappId) and android/key.properties signing.")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
