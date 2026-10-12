import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.omni_smsnew"
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
        applicationId = "com.example.omni_smsnew"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 33
        versionCode = 1
        versionName = "1.0"
        
        // NDK abi filters removed to allow split-per-abi builds
        // ndk {
        //     abiFilters += listOf("arm64-v8a")
        // }
    }

    signingConfigs {
        create("release") {
            // SÉCURITÉ : les secrets de signature ne doivent JAMAIS être hardcodés.
            // Ils sont lus depuis android/key.properties (hors dépôt) ou des
            // variables d'environnement CI. Voir README sécurité.
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
            }
            val storeFilePath = keystoreProperties.getProperty("storeFile")
                ?: System.getenv("OMNISMS_KEYSTORE_PATH")
            val storePasswordEnv = keystoreProperties.getProperty("storePassword")
                ?: System.getenv("OMNISMS_STORE_PASSWORD")
            val keyAliasEnv = keystoreProperties.getProperty("keyAlias")
                ?: System.getenv("OMNISMS_KEY_ALIAS")
            val keyPasswordEnv = keystoreProperties.getProperty("keyPassword")
                ?: System.getenv("OMNISMS_KEY_PASSWORD")

            storeFile = storeFilePath?.let { file(it) }
            storePassword = storePasswordEnv
            keyAlias = keyAliasEnv
            keyPassword = keyPasswordEnv
        }
    }

    buildTypes {
        release {
            // Signer seulement si la config keystore est disponible (sinon debug)
            signingConfig = if (signingConfigs.getByName("release").storeFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
