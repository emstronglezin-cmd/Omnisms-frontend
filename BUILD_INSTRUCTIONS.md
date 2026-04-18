# 🚀 Instructions de Build - OmniSMS v2.1.0

## ✅ PRÉPARATION AVANT LE BUILD

### 1. Vérification de l'environnement

**Exigences minimales:**
- **RAM**: 8 GB minimum (recommandé: 16 GB)
- **Espace disque**: 10 GB disponibles
- **OS**: Windows 10/11, macOS 10.15+, ou Linux
- **Java JDK**: Version 17 (obligatoire pour Android)
- **Flutter SDK**: Version 3.10+ (recommandé: 3.24+)
- **Android SDK**: API 23-34 installés

### 2. Installation de Flutter

```bash
# Télécharger Flutter
# Windows: https://docs.flutter.dev/get-started/install/windows
# macOS: https://docs.flutter.dev/get-started/install/macos
# Linux: https://docs.flutter.dev/get-started/install/linux

# Vérifier l'installation
flutter doctor -v

# Si des problèmes apparaissent, installez les composants manquants
```

### 3. Installation d'Android Studio

1. Télécharger: https://developer.android.com/studio
2. Installer les composants:
   - Android SDK Platform 34
   - Android SDK Build-Tools 34.0.0
   - Android SDK Platform-Tools
   - Android SDK Command-line Tools
   - Google Play Services

### 4. Configuration Java JDK 17

**Windows:**
```bash
# Télécharger JDK 17 depuis:
# https://adoptium.net/temurin/releases/?version=17

# Définir JAVA_HOME dans les variables d'environnement système:
JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.9.9-hotspot
Path=%JAVA_HOME%\bin;%Path%
```

**macOS:**
```bash
# Installer via Homebrew
brew install openjdk@17

# Lier Java
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk \
  /Library/Java/JavaVirtualMachines/openjdk-17.jdk

# Ajouter à ~/.zshrc ou ~/.bash_profile
export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-17.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install openjdk-17-jdk

# Vérifier
java -version  # doit afficher version 17.x
```

---

## 📥 RÉCUPÉRATION DU CODE

```bash
# Cloner le repository
git clone https://github.com/emstronglezin-cmd/Omnisms-frontend.git
cd Omnisms-frontend

# Basculer sur la branche de production
git checkout feature/full-integration-v2

# Vérifier la version
cat pubspec.yaml | grep "version:"
# Doit afficher: version: 2.1.0+3
```

---

## 🔧 CONFIGURATION FIREBASE & BACKEND

### Firebase (déjà configuré)

Le fichier `android/app/google-services.json` est déjà présent avec:
- **Project ID**: `omnisms-b98c5`
- **API Key**: `AIzaSyD3Yur6Q5IvcDI_bC9YuLFNC4jvgEREtBQ`

✅ **Rien à modifier** sauf si vous changez de projet Firebase.

### Backend Configuration

Le fichier `lib/config/api_config.dart` pointe déjà vers:
- **HTTP**: `http://51.15.89.72:5000`
- **WebSocket**: `ws://51.15.89.72:5000/ws`

✅ **Backend prêt** si le serveur tourne sur cette IP.

### Start.io Ads (optionnel)

Dans `lib/config/api_config.dart`, ligne 34:
```dart
static const String startIoAppId = '210637982';
```

✅ **ID présent**, les pubs devraient fonctionner.

---

## 🛠️ INSTALLATION DES DÉPENDANCES

```bash
# Nettoyer les fichiers temporaires
flutter clean

# Télécharger toutes les dépendances
flutter pub get

# Vérifier qu'il n'y a pas d'erreurs
flutter doctor
flutter pub outdated
```

**Si vous avez des erreurs de dépendances**, essayez:
```bash
flutter pub upgrade --major-versions
flutter pub get
```

---

## 📦 BUILD APK (RECOMMANDÉ POUR TESTS)

### Option A: APK pour une architecture (plus petit, ~20 MB)

```bash
# ARM64 (99% des téléphones modernes)
flutter build apk --release --target-platform android-arm64

# ARMv7 (anciens téléphones)
flutter build apk --release --target-platform android-arm

# x86_64 (émulateurs)
flutter build apk --release --target-platform android-x64
```

**Fichiers générés:**
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

### Option B: APK universel (plus gros, ~60 MB, compatible tous appareils)

```bash
flutter build apk --release
```

**Fichier généré:**
- `build/app/outputs/flutter-apk/app-release.apk`

### Option C: APK splitté par architecture (recommandé)

```bash
flutter build apk --release --split-per-abi
```

**Fichiers générés** (3 APKs):
- `app-arm64-v8a-release.apk` (~20 MB) → téléphones modernes
- `app-armeabi-v7a-release.apk` (~18 MB) → anciens téléphones
- `app-x86_64-release.apk` (~22 MB) → émulateurs

---

## 🏪 BUILD AAB (POUR GOOGLE PLAY STORE)

```bash
flutter build appbundle --release
```

**Fichier généré:**
- `build/app/outputs/bundle/release/app-release.aab` (~25 MB)

**⚠️ Important:** Le fichier AAB doit être signé pour être uploadé sur le Play Store.

---

## 🔐 SIGNATURE DE L'APK/AAB (obligatoire pour distribution)

### 1. Vérifier le keystore existant

```bash
ls -la android/
# Cherchez: omnisms-keystore.jks
```

Si le fichier existe, il est déjà configuré dans `android/app/build.gradle.kts`:
- **Alias**: `omnisms-key`
- **Mot de passe**: `omnisms2026`

### 2. Si le keystore n'existe pas, créez-le:

```bash
cd android/

# Générer un nouveau keystore
keytool -genkey -v -keystore omnisms-keystore.jks \
  -alias omnisms-key \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass omnisms2026 -keypass omnisms2026

# Remplir les informations:
# Nom: OmniSMS Team
# Organisation: OmniSMS
# Ville: [Votre ville]
# Pays: [Code pays, ex: FR]
```

### 3. Vérifier la signature du build

```bash
# Après le build, vérifier que l'APK est bien signé
cd build/app/outputs/flutter-apk/
jarsigner -verify -verbose -certs app-arm64-v8a-release.apk

# Doit afficher: jar verified.
```

---

## 📱 INSTALLATION SUR UN APPAREIL

### Via câble USB (ADB)

```bash
# Activer le débogage USB sur votre téléphone:
# Paramètres > À propos du téléphone > Appuyer 7x sur "Numéro de build"
# Paramètres > Options développeur > Activer "Débogage USB"

# Connecter le téléphone via USB

# Vérifier que le téléphone est détecté
adb devices

# Installer l'APK
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Si l'app est déjà installée, utiliser -r (réinstaller):
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### Via transfert de fichier

1. Copier l'APK sur votre téléphone (câble USB, Bluetooth, email, etc.)
2. Ouvrir le gestionnaire de fichiers sur le téléphone
3. Trouver l'APK et appuyer dessus
4. Autoriser l'installation depuis des sources inconnues si demandé
5. Installer

---

## 🐛 RÉSOLUTION DES PROBLÈMES COURANTS

### Erreur: "Gradle daemon disappeared"

**Cause:** Manque de RAM ou Gradle crashe.

**Solutions:**

1. **Augmenter la mémoire Gradle:**
```bash
# Éditer android/gradle.properties
echo "org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m" >> android/gradle.properties
```

2. **Nettoyer le cache Gradle:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

3. **Désactiver le daemon Gradle:**
```bash
cd android
./gradlew assembleRelease --no-daemon
```

### Erreur: "Android SDK not found"

**Solution:**
```bash
# Définir la variable d'environnement ANDROID_HOME

# Windows (PowerShell):
$env:ANDROID_HOME = "C:\Users\VotreNom\AppData\Local\Android\Sdk"

# macOS/Linux:
export ANDROID_HOME=$HOME/Library/Android/sdk  # macOS
export ANDROID_HOME=$HOME/Android/Sdk          # Linux
```

### Erreur: "Java version incorrect"

**Solution:**
```bash
# Vérifier la version Java
java -version

# Doit afficher: openjdk version "17.x"

# Si incorrect, installer Java 17 (voir section 4)
```

### Erreur: "Plugin audioplayers_android requires compileSdk version 35"

**Solution:**
```bash
# Éditer android/app/build.gradle.kts
# Changer:
compileSdk = 35  # au lieu de 34

# Ou mettre à jour audioplayers:
flutter pub upgrade audioplayers
```

### Erreur: "Out of memory"

**Solutions:**

1. Fermer toutes les autres applications
2. Augmenter la RAM Gradle (voir android/gradle.properties)
3. Builder sur un autre ordinateur avec plus de RAM
4. Utiliser un service de build cloud (Codemagic, Bitrise, etc.)

### Build trop lent

**Optimisations:**
```bash
# Désactiver les builds inutiles:
flutter build apk --release --target-platform android-arm64 \
  --no-tree-shake-icons \
  --no-shrink

# Builder en mode debug (plus rapide mais plus gros):
flutter build apk --debug
```

---

## ✅ CHECKLIST AVANT PUBLICATION

- [ ] **Build APK/AAB réussi** sans erreurs
- [ ] **APK/AAB signé** avec le keystore
- [ ] **Testé sur un vrai appareil** Android
- [ ] **Backend accessible** (http://51.15.89.72:5000)
- [ ] **Firebase configuré** (notifications push testées)
- [ ] **Start.io Ads fonctionnent** (ID: 210637982)
- [ ] **Permissions demandées** (caméra, micro, notifications)
- [ ] **Connexions WebSocket** fonctionnelles
- [ ] **Messages envoyés/reçus** correctement
- [ ] **Contacts affichés** depuis le backend
- [ ] **Groupes fonctionnels**
- [ ] **Transcription audio** testée
- [ ] **Abonnement/Paiements** testés
- [ ] **Aucun crash** au démarrage ni pendant l'utilisation

---

## 📊 TAILLES APPROXIMATIVES DES BUILDS

| Type de build | Taille | Compatibilité |
|---------------|--------|---------------|
| APK ARM64 | ~20 MB | Téléphones modernes (2016+) |
| APK ARMv7 | ~18 MB | Anciens téléphones |
| APK x86_64 | ~22 MB | Émulateurs |
| APK universel | ~60 MB | Tous appareils |
| AAB (Play Store) | ~25 MB | Tous appareils (split auto) |

---

## 🚀 DÉPLOIEMENT SUR GOOGLE PLAY STORE

1. **Créer un compte Google Play Console** (25$ unique)
2. **Créer une nouvelle application**
3. **Remplir les informations** (nom, description, screenshots)
4. **Uploader le fichier AAB** (`app-release.aab`)
5. **Configurer les politiques** (confidentialité, contenu)
6. **Soumettre pour review**

**Durée de review:** 1-7 jours

---

## 📞 SUPPORT

- **Repository GitHub:** https://github.com/emstronglezin-cmd/Omnisms-frontend
- **Branche actuelle:** `feature/full-integration-v2`
- **Version:** 2.1.0 (build 3)
- **Date:** 2026-03-06

**En cas de problème:**
1. Vérifier les logs: `flutter doctor -v`
2. Nettoyer: `flutter clean && flutter pub get`
3. Consulter les issues GitHub
4. Rebuild depuis zéro si nécessaire

---

## 🎯 COMMANDES RAPIDES (RÉSUMÉ)

```bash
# Cloner et préparer
git clone https://github.com/emstronglezin-cmd/Omnisms-frontend.git
cd Omnisms-frontend
git checkout feature/full-integration-v2
flutter clean && flutter pub get

# Build APK (recommandé)
flutter build apk --release --split-per-abi

# Build AAB (Play Store)
flutter build appbundle --release

# Installer sur téléphone
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Vérifier
adb logcat | grep -i flutter
```

**Temps estimé:** 15-30 minutes (selon votre ordinateur)

---

**✅ BUILD PRÊT À COMPILER !**

Tous les fichiers sont prêts sur GitHub. Il suffit de suivre ce guide étape par étape.
