import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.omnisms.app"
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
        // IMPORTANT — identifiant définitif (choix validé par l'éditeur).
        // Il est IMPOSSIBLE de le changer après la première publication sur
        // Google Play : toute modification créerait une fiche distincte.
        // DÉCISION OBLIGATOIRE : identique à l'identifiant iOS.
        // ATTENTION — android/app/google-services.json est encore enregistré
        // pour l'ancien paquet « omnisms.app ». Il DOIT être régénéré dans la
        // console Firebase pour « com.omnisms.app » avant d'activer FCM ou
        // Crashlytics ; sans cela, le greffon Gradle échouera (« No matching
        // client found for package name »). Un test le rappelle.
        applicationId = "com.omnisms.app"
        minSdk = flutter.minSdkVersion  // 24 (Android 7.0) — défaut Flutter 3.47
        // Google Play exige Android 16 (API 36) depuis le 31/08/2026 pour
        // toute nouvelle application et toute mise à jour. On suit donc la
        // valeur du SDK Flutter (36) au lieu d'une valeur figée.
        targetSdk = flutter.targetSdkVersion
        // Version lue depuis pubspec.yaml (2.5.0+1) : une seule source de
        // vérité, plus de désynchronisation Gradle/pubspec.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
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
