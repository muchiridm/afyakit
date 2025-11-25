plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.afyakit.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.afyakit.app" // overridden per flavor
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += listOf("tenant")

    productFlavors {
        create("afyakit") {
            dimension = "tenant"
            applicationId = "com.afyakit.app"
            resValue("string", "app_name", "AfyaKit")
            manifestPlaceholders["host1"] = "afyakit.app"
            manifestPlaceholders["host2"] = "www.afyakit.app"
        }
        create("danabtmc") {
            dimension = "tenant"
            applicationId = "com.danabtmc.app"
            resValue("string", "app_name", "Danab TMC")
            manifestPlaceholders["host1"] = "danabtmc.com"
            manifestPlaceholders["host2"] = "www.danabtmc.com"
        }
        create("dawapap") {
            dimension = "tenant"
            applicationId = "com.dawapap.app"
            resValue("string", "app_name", "DawaPap")
            manifestPlaceholders["host1"] = "dawapap.com"
            manifestPlaceholders["host2"] = "www.dawapap.com"
        }
        create("rpmoc") {
            dimension = "tenant"
            applicationId = "com.rpmoc.app"
            resValue("string", "app_name", "RPMO Clinic")
            manifestPlaceholders["host1"] = "rpmoc.afyakit.app"
            manifestPlaceholders["host2"] = "afyakit.app"
        }
    }

    buildTypes {
        getByName("debug") {
            // absolutely no shrinking in debug
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("release") {
            // either keep shrinking OFF for now:
            isMinifyEnabled = false
            isShrinkResources = false

            // keep debug signing until real keystore
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

apply(plugin = "com.google.gms.google-services")
