plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Plugin Flutter (wajib)
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase google-services (opsional kalau pakai Firebase)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.apps_runara"

    // compileSdk yg aman untuk Flutter 3.35.x
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.apps_runara"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // sementara pakai debug keystore
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.android.gms:play-services-auth:21.4.0")

    // ==== Firebase (opsional) ====
    implementation(platform("com.google.firebase:firebase-bom:34.2.0"))
    implementation("com.google.firebase:firebase-analytics")

    // ==== Facebook Login (via plugin flutter_facebook_auth) ====
    // Tidak perlu tambahkan dependensi SDK native lain
    // plugin Flutter akan bawa transitive deps sendiri.

    // Lainnya (contoh)
    implementation("androidx.core:core-ktx:1.17.0")
}
