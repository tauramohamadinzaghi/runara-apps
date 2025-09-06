pluginManagement {
    val properties = java.util.Properties()
    file("local.properties").inputStream().use { properties.load(it) }
    val flutterSdkPath = properties.getProperty("flutter.sdk")
        ?: throw GradleException("flutter.sdk not set in local.properties")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // penting agar resolve flutter_embedding_*
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // Upgrade AGP & Kotlin supaya kompatibel SDK 36
    id("com.android.application") version "8.12.2" apply false
    id("org.jetbrains.kotlin.android") version "2.2.10" apply false

    // (opsional jika pakai Firebase)
    id("com.google.gms.google-services") version "4.4.3" apply false
}

include(":app")
