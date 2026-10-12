import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing secrets are developer-owned and must never be committed or added
// to CI. An explicit release task must fail when secure signing is absent.
val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties()
if (releasePropertiesFile.isFile) {
    FileInputStream(releasePropertiesFile).use { releaseProperties.load(it) }
}
val requiredReleaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseSigningConfigured = requiredReleaseSigningKeys.all {
    !releaseProperties.getProperty(it).isNullOrBlank()
} && releasePropertiesFile.isFile
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseTaskRequested) {
    require(releaseSigningConfigured) {
        "Android release signing is missing. Set android/key.properties locally; never use the debug key."
    }
    val keystorePath = rootProject.file(releaseProperties.getProperty("storeFile"))
    require(keystorePath.isFile) {
        "Android release keystore is missing. Verify the private storeFile path."
    }
}


android {
    namespace = "com.example.rokter_badhon"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.rokter_badhon"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                val keystorePath = rootProject.file(releaseProperties.getProperty("storeFile"))
                storeFile = keystorePath
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Never sign a production candidate using the Android debug key.
            // If no private key exists, debug CI can still build normally.
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

flutter {
    source = "../.."
}
