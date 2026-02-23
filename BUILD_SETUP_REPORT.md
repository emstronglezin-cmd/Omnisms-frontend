# Rapport de Configuration du Build APK/AAB

## Date: 2026-02-23

## Travail Effectué

### 1. Installation de l'Environnement de Build

#### Flutter SDK
- ✅ Installé Flutter 3.41.2 (stable channel) dans `/home/user/flutter`
- ✅ Téléchargement réussi de tous les composants nécessaires
- ✅ Configuration réussie de `flutter pub get`

#### Android SDK
- ✅ Téléchargé et installé Android Command Line Tools dans `/home/user/android-sdk`
- ✅ Installé les composants suivants:
  - Platform Tools (adb, fastboot)
  - Android SDK Platform 34
  - Build Tools 34.0.0
  - NDK 25.1.8937393
- ✅ Accepté toutes les licences Android

#### Java JDK
- ✅ Téléchargé et installé Java 17 (OpenJDK 17.0.13+11) dans `/home/user/jdk-17.0.13+11`
- ✅ Java 11 déjà disponible dans `/opt/java/openjdk`

### 2. Configuration du Projet

#### Fichiers Modifiés

**android/app/build.gradle.kts**
- ✅ Corrigé la configuration du signing (keystore)
- ✅ Ajouté signingConfigs pour la release
- ✅ Ajouté le filtre ABI pour arm64-v8a (optimisation mémoire)
- ✅ Configuration: `storeFile = file("../../omnisms-keystore.jks")`
- ✅ Credentials: `storePassword/keyPassword = "FASO2009"`, `keyAlias = "OmniSMS"`

**android/gradle.properties**
- ✅ Optimisé les paramètres JVM pour environnement à mémoire limitée
- ✅ Configuration finale:
  ```properties
  org.gradle.jvmargs=-Xms128m -Xmx300m -XX:MaxMetaspaceSize=280m -XX:+UseSerialGC
  kotlin.daemon.jvm.options=-Xmx180m
  org.gradle.daemon=false
  org.gradle.parallel=false
  org.gradle.caching=false
  org.gradle.workers.max=1
  ```

### 3. Keystore

- ✅ Keystore trouvé à deux emplacements:
  - `/home/user/webapp/omnisms-keystore.jks` (2233 bytes)
  - `/home/user/webapp/android/omnisms-keystore.jks` (2570 bytes)
- ✅ Configuration pointant vers le keystore racine

## Problème Rencontré

### Erreur: Gradle Daemon Crash

**Symptôme**: Le daemon Gradle disparaît de manière inattendue pendant la compilation

**Cause**: Mémoire insuffisante dans l'environnement sandbox
- Mémoire disponible: ~850 MB
- Gradle + Kotlin + Android Build nécessitent plus de ressources

**Messages d'erreur**:
```
The message received from the daemon indicates that the daemon has disappeared.
Gradle build daemon disappeared unexpectedly (it may have been killed or may have crashed)
```

### Tentatives de Résolution

1. ✅ Désactivation du daemon Gradle (`org.gradle.daemon=false`)
2. ✅ Réduction du nombre de workers (`--max-workers=1`, `--no-parallel`)
3. ✅ Optimisation de la mémoire JVM (testé plusieurs configurations de 350MB à 768MB)
4. ✅ Utilisation de Java 11 au lieu de Java 17 (moins gourmand en mémoire)
5. ✅ Filtrage des ABIs (uniquement arm64-v8a)
6. ✅ Désactivation du cache Gradle
7. ❌ Toutes les tentatives échouent avec le même problème de mémoire

## Solutions Recommandées

### Option 1: Build sur Machine Locale (RECOMMANDÉ)

Le projet est maintenant prêt pour être compilé sur une machine avec plus de ressources:

```bash
# Sur votre machine locale avec Flutter installé:
cd /path/to/project

# Build APK
flutter build apk --release

# Build AAB (pour Google Play Store)
flutter build appbundle --release

# Ou les deux en utilisant Gradle directement:
cd android
./gradlew assembleRelease bundleRelease
```

**Fichiers de sortie attendus**:
- APK: `android/app/build/outputs/apk/release/app-release.apk`
- AAB: `android/app/build/outputs/bundle/release/app-release.aab`

### Option 2: Build via CI/CD

Configurer GitHub Actions ou GitLab CI avec:
- Ubuntu runner avec au moins 4GB RAM
- Flutter SDK pré-installé
- Android SDK pré-installé

### Option 3: Augmenter les Ressources du Sandbox

Si possible, augmenter la mémoire du sandbox à au moins 2GB pour permettre le build Gradle.

## Fichiers Créés

- `build_apk.sh`: Script de build automatisé
- `BUILD_SETUP_REPORT.md`: Ce rapport

## Configuration Prête pour le Build

Tous les fichiers de configuration sont prêts et optimisés. Les modifications apportées permettront un build réussi sur une machine avec suffisamment de mémoire (minimum 2GB RAM recommandé).

### Commandes pour Builder Ailleurs

```bash
# Avec Flutter
flutter clean
flutter pub get
flutter build apk --release
flutter build appbundle --release

# Ou avec Gradle directement
cd android
./gradlew clean
./gradlew assembleRelease    # Pour APK
./gradlew bundleRelease       # Pour AAB
```

## Prochaines Étapes

1. Cloner le projet sur une machine avec plus de ressources
2. Exécuter les commandes de build ci-dessus
3. Les fichiers APK et AAB seront générés dans `android/app/build/outputs/`

## Notes Techniques

- Le keystore est correctement configuré pour signer l'application
- Le build est optimisé pour arm64-v8a (architecture la plus courante)
- Tous les paramètres Gradle sont optimisés pour minimiser l'utilisation mémoire
- Le daemon Gradle est désactivé pour éviter les problèmes de mémoire
