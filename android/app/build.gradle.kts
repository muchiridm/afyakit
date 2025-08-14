plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.afyakit.app" // tidy namespace (can be anything)
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
        // Placeholder; per-flavor applicationId below overrides this
        applicationId = "com.afyakit.app"
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
}

    buildTypes {
        release {
            // keep debug signing until you wire a real keystore
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

apply(plugin = "com.google.gms.google-services")

