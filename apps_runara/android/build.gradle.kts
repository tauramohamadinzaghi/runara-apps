import org.gradle.api.file.Directory

// ===== buildscript: classpath plugin yang dibutuhkan =====
buildscript {
    // versi Kotlin yang dipakai modul app
    extra["kotlin_version"] = "2.1.0"

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    dependencies {
        // Android Gradle Plugin
        classpath("com.android.tools.build:gradle:8.12.2")
        // Google Services (untuk google-services.json)
        classpath("com.google.gms:google-services:4.4.3")
    }
}

// ===== repositori untuk semua subproject (app, plugin, dll) =====
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ===== redirect lokasi build ke ../../build (root flutter) =====
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// setiap subproject -> ../../build/<nama-modul>
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// jaga urutan evaluasi (khas template Flutter)
subprojects {
    project.evaluationDependsOn(":app")
}

// tugas clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
