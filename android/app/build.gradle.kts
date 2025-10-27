import java.util.Properties // <-- Add this line
import java.io.FileInputStream // <-- Add this line


// ... (rest of your build.gradle.kts file starts here)
// plugins { ... }
// android { ... }
// etc.

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- هذا هو الكود الجديد بلغة Kotlin ---
val keystoreProperties = Properties()
// Point directly to the file inside the 'android' folder
val keystorePropertiesFile = rootProject.project(":").file("key.properties")
if (keystorePropertiesFile.isFile) { // <-- استخدم isFile للتحقق
    FileInputStream(keystorePropertiesFile).use { fis ->
        keystoreProperties.load(fis)
    }
} else {
    println("Warning: key.properties file not found at ${keystorePropertiesFile.absolutePath}")
}
// --- نهاية الكود الجديد ---

android {
    namespace = "com.example.myapprun"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "iq.ameerazax.velin"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.containsKey("storeFile")) { // <-- تحقق من وجود المفتاح
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            } else {
                println("Warning: Keystore properties not found. Using debug signing for release.")
                // Fallback to debug signing if properties are missing
                //signingConfig = signingConfigs.getByName("debug")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // ...
            signingConfig = signingConfigs.getByName("release") // <-- تأكد من هذا
        }
    }
}

flutter {
    source = "../.."
}
