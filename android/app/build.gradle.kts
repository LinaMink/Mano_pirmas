plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.lock_screen_love"
    compileSdk = 36  // ✅ PATAISYTA: was 34
    ndkVersion = "27.0.12077973"  // ✅ PATAISYTA: was 25.1.8937393

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.lock_screen_love"
        minSdk = flutter.minSdkVersion  // ✅ Keep this
        targetSdk = 36  // ✅ PATAISYTA: was 34
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    
    // Firebase products
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-crashlytics-ktx")
    implementation("com.google.firebase:firebase-appcheck")
    
    // Multidex
    implementation("androidx.multidex:multidex:2.0.1")
}
