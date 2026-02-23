# Guide de Build APK/AAB - OmniSMS

## Prérequis

1. **Flutter SDK** installé (version stable recommandée)
2. **Android SDK** avec les outils de build
3. **Java JDK** 11 ou supérieur
4. **Keystore** configuré (`omnisms-keystore.jks`)

## Configuration du Keystore

Le projet est déjà configuré avec un keystore. Les informations sont dans `android/key.properties`:

```properties
storePassword=omnisms2026
keyPassword=omnisms2026
keyAlias=omnisms-key
storeFile=release-key.jks
```

Le fichier `omnisms-keystore.jks` se trouve à la racine du projet Android.

## Commandes de Build

### 1. Installer les dépendances

```bash
flutter pub get
```

### 2. Vérifier la configuration

```bash
flutter doctor
```

Assurez-vous que Flutter et Android sont correctement configurés.

### 3. Nettoyer le projet (optionnel)

```bash
flutter clean
flutter pub get
```

### 4. Build APK (Release)

#### APK Standard
```bash
flutter build apk --release
```

Le fichier sera généré dans: `build/app/outputs/flutter-apk/app-release.apk`

#### APK par ABI (taille réduite)
```bash
flutter build apk --split-per-abi --release
```

Génère 3 APK optimisés:
- `app-arm64-v8a-release.apk` (pour appareils 64-bit modernes)
- `app-armeabi-v7a-release.apk` (pour appareils 32-bit)
- `app-x86_64-release.apk` (pour émulateurs/tablettes x86)

### 5. Build AAB (Android App Bundle)

```bash
flutter build appbundle --release
```

Le fichier sera généré dans: `build/app/outputs/bundle/release/app-release.aab`

**Note**: AAB est le format requis pour le Google Play Store.

## Optimisations de Build

### Build avec obfuscation (recommandé pour production)

```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
```

Avantages:
- Code Dart obfusqué (plus difficile à reverse-engineer)
- Fichiers de debug séparés pour le dépannage
- Taille réduite de l'app

### Build avec analyse de taille

```bash
flutter build apk --release --analyze-size
```

Affiche un rapport détaillé de la taille de l'application.

## Vérification du Build

### Inspecter l'APK

```bash
# Lister le contenu
unzip -l build/app/outputs/flutter-apk/app-release.apk

# Vérifier la signature
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

### Tester l'APK

```bash
# Installer sur un appareil connecté
flutter install --release

# Ou avec adb
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Tailles Attendues

- **APK Standard**: ~40-60 MB
- **APK arm64**: ~20-25 MB (recommandé)
- **AAB**: ~35-50 MB

## Configuration Build (build.gradle.kts)

Le projet est configuré avec:

```kotlin
defaultConfig {
    applicationId = "com.omnisms.app"
    minSdk = 23  // Android 6.0+
    targetSdk = 34  // Android 14
    versionCode = 1
    versionName = "1.0.0"
}

buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        signingConfig = signingConfigs.getByName("release")
        proguardFiles(...)
    }
}
```

## Résolution de Problèmes

### Erreur: "Keystore not found"

Vérifiez que:
1. Le fichier `omnisms-keystore.jks` existe dans `android/`
2. Le chemin dans `key.properties` est correct

### Erreur: "Build failed"

```bash
# Nettoyer et reconstruire
flutter clean
cd android && ./gradlew clean
cd ..
flutter pub get
flutter build apk --release
```

### Erreur: "Out of memory"

Augmentez la mémoire allouée à Gradle dans `android/gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx4096m
```

### Erreur: "SDK not found"

Vérifiez la variable d'environnement:
```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

## Distribution

### Installation Directe (APK)

1. Activez "Sources inconnues" sur l'appareil
2. Transférez l'APK sur l'appareil
3. Ouvrez le fichier pour l'installer

### Google Play Store (AAB)

1. Créez une application sur Google Play Console
2. Uploadez le fichier `app-release.aab`
3. Remplissez les informations de l'application
4. Soumettez pour révision

## Checklist de Release

- [ ] Version mise à jour dans `pubspec.yaml`
- [ ] Tests réussis (`flutter test`)
- [ ] Build APK généré sans erreur
- [ ] Build AAB généré sans erreur
- [ ] APK testé sur appareil réel
- [ ] Fonctionnalités backend testées
- [ ] Permissions vérifiées dans AndroidManifest.xml
- [ ] Icône d'application configurée
- [ ] Splash screen configuré (optionnel)

## Scripts Utiles

### Build All

```bash
#!/bin/bash
echo "🏗️  Build APK et AAB..."

# Nettoyer
flutter clean
flutter pub get

# Build APK optimisé
echo "📱 Build APK..."
flutter build apk --split-per-abi --release --obfuscate --split-debug-info=build/debug-info

# Build AAB
echo "📦 Build AAB..."
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info

echo "✅ Builds terminés!"
echo "APK: build/app/outputs/flutter-apk/"
echo "AAB: build/app/outputs/bundle/release/"
```

Sauvegardez ce script comme `build_all.sh` et exécutez:

```bash
chmod +x build_all.sh
./build_all.sh
```

## Support

Pour toute question sur le build process:
1. Consultez la documentation Flutter: https://docs.flutter.dev/deployment/android
2. Vérifiez les logs: `flutter build apk --release --verbose`
3. Consultez le fichier `BACKEND_SETUP.md` pour la configuration API

---

**Version**: 1.0.0  
**Date**: 21 février 2026  
**Status**: ✅ Prêt pour production
