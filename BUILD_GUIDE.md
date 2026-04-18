# 🚀 GUIDE COMPLET DE BUILD - OmniSMS v2.1.0

## ❌ POURQUOI LE BUILD ÉCHOUE DANS LE SANDBOX

Le daemon Gradle nécessite **plus de 2 GB de RAM** pour compiler l'application Android.  
Le sandbox dispose de **moins de 1 GB de RAM disponible**.  
Résultat : Le daemon est tué par le système (Out of Memory).

**Message d'erreur** :
```
Gradle build daemon disappeared unexpectedly
(it may have been killed or may have crashed)
```

---

## ✅ SOLUTION : BUILD SUR VOTRE MACHINE

### Prérequis

1. **Flutter SDK** installé (version 3.4.0+)
2. **Android SDK** installé avec :
   - SDK Platform 34 (Android 14)
   - Build-Tools 34.0.0
   - Command-line tools
3. **Java JDK 17** installé
4. **Au moins 4 GB de RAM disponible**

---

## 📦 MÉTHODE 1 : Script Automatique (Recommandé)

### Étape 1 : Cloner le Repository

```bash
git clone https://github.com/emstronglezin-cmd/Omnisms-frontend.git
cd Omnisms-frontend
```

### Étape 2 : Basculer sur la Bonne Branche

```bash
git checkout feature/full-integration-v2
```

### Étape 3 : Exécuter le Script de Build

```bash
chmod +x build_app.sh
./build_app.sh
```

Le script vous demandera ce que vous voulez générer :
1. APK universel
2. APK split (par architecture)
3. AAB (Google Play)
4. Tout

**Temps estimé** : 5-10 minutes

---

## 📦 MÉTHODE 2 : Commandes Manuelles

### Étape 1 : Préparer l'Environnement

```bash
cd Omnisms-frontend
git checkout feature/full-integration-v2

# Vérifier que vous êtes sur la bonne version
cat pubspec.yaml | grep version
# Doit afficher: version: 2.1.0+3
```

### Étape 2 : Nettoyer

```bash
flutter clean
rm -rf build/
```

### Étape 3 : Installer les Dépendances

```bash
flutter pub get
```

**Vérifiez qu'il n'y a pas d'erreurs**. Si vous voyez :
```
Changed X dependencies!
```
C'est bon signe.

### Étape 4 : Analyser le Code (Optionnel)

```bash
flutter analyze
```

Cela vérifie qu'il n'y a pas d'erreurs dans le code.

### Étape 5 : Générer l'APK

#### Option A : APK Universel (Simple, 1 fichier)

```bash
flutter build apk --release
```

**Fichier généré** :
```
build/app/outputs/flutter-apk/app-release.apk
```

**Taille** : ~35-45 MB  
**Compatible** : Tous les appareils

#### Option B : APK Split (Recommandé, 3 fichiers)

```bash
flutter build apk --split-per-abi --release
```

**Fichiers générés** :
```
build/app/outputs/flutter-apk/
├── app-armeabi-v7a-release.apk  (~18 MB - Android 32-bit)
├── app-arm64-v8a-release.apk    (~20 MB - Android 64-bit) ⭐ PRINCIPAL
└── app-x86_64-release.apk       (~22 MB - Émulateurs)
```

**Avantage** : Taille réduite (~20 MB au lieu de 40 MB)

### Étape 6 : Générer l'AAB (Google Play)

```bash
flutter build appbundle --release
```

**Fichier généré** :
```
build/app/outputs/bundle/release/app-release.aab
```

**Taille** : ~25 MB  
**Usage** : Publication sur Google Play Store

---

## 🔧 RÉSOLUTION DES PROBLÈMES

### Problème 1 : "Flutter command not found"

**Solution** :
```bash
# Trouvez où Flutter est installé
which flutter

# Si non trouvé, ajoutez au PATH
export PATH="$PATH:/path/to/flutter/bin"

# Ou ajoutez dans ~/.bashrc ou ~/.zshrc
echo 'export PATH="$PATH:/path/to/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Problème 2 : "Android SDK not found"

**Solution** :
```bash
# Définir ANDROID_HOME
export ANDROID_HOME=/path/to/android/sdk
export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools"

# Vérifier
echo $ANDROID_HOME
```

### Problème 3 : "Java version incompatible"

**Solution** :
```bash
# Vérifier la version Java
java -version

# Devrait afficher Java 17
# Si pas Java 17, installez-le
```

### Problème 4 : "Gradle daemon died"

**Causes** :
- Pas assez de RAM
- Java OutOfMemoryError

**Solutions** :

#### A. Augmenter la mémoire Gradle

Éditer `android/gradle.properties` :
```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m
org.gradle.daemon=true
org.gradle.parallel=false
```

#### B. Fermer d'autres applications

Libérez de la RAM en fermant :
- Navigateurs web
- IDEs (Android Studio, VSCode)
- Autres applications lourdes

#### C. Build avec options allégées

```bash
flutter build apk --release \
  --no-tree-shake-icons \
  --target-platform android-arm64
```

Cela génère uniquement l'APK ARM64 (le plus utilisé).

### Problème 5 : "Build failed with an exception"

**Solution** :
```bash
# Nettoyer complètement
flutter clean
rm -rf build/
rm -rf .dart_tool/
rm -rf android/.gradle
rm -rf android/app/build

# Réinstaller
flutter pub get

# Rebuild
flutter build apk --release
```

### Problème 6 : "Firebase configuration not found"

**Vérification** :
```bash
# Le fichier google-services.json doit exister
ls -la android/app/google-services.json

# Si absent, il est dans le repository GitHub
git pull origin feature/full-integration-v2
```

---

## 📲 INSTALLATION SUR TÉLÉPHONE

### Méthode 1 : ADB (Appareil Connecté)

```bash
# Activer le débogage USB sur le téléphone
# Paramètres → À propos → Taper 7x sur "Numéro de build"
# Paramètres → Options développeur → Débogage USB ✓

# Connecter le téléphone en USB

# Vérifier la connexion
adb devices
# Doit afficher: XXXXXX device

# Installer l'APK
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Lancer l'application
adb shell am start -n omnisms.app/.MainActivity
```

### Méthode 2 : Transfert Direct

1. **Copier l'APK** sur votre téléphone :
   - Via câble USB → Copier dans dossier `Téléchargements/`
   - Via Email → S'envoyer l'APK par email
   - Via Cloud → Google Drive, Dropbox, etc.

2. **Ouvrir l'APK** sur le téléphone :
   - Aller dans `Téléchargements/`
   - Cliquer sur `app-arm64-v8a-release.apk`

3. **Autoriser** l'installation de sources inconnues si demandé

4. **Installer** et lancer

### Méthode 3 : Flutter Install

```bash
# Téléphone connecté en USB
flutter install --release
```

---

## 📊 VÉRIFICATION DES BUILDS

### Tailles Attendues

| Fichier | Taille Approximative |
|---------|---------------------|
| app-release.apk (universel) | 35-45 MB |
| app-armeabi-v7a-release.apk | 18-20 MB |
| app-arm64-v8a-release.apk | 20-22 MB ⭐ |
| app-x86_64-release.apk | 22-24 MB |
| app-release.aab | 25-30 MB |

### Commandes de Vérification

```bash
# Lister les fichiers générés
ls -lh build/app/outputs/flutter-apk/
ls -lh build/app/outputs/bundle/release/

# Vérifier le contenu d'un APK
unzip -l build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | head -20

# Vérifier la signature
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🎯 QUEL FICHIER UTILISER ?

### Pour Installation Directe
**Utilisez** : `app-arm64-v8a-release.apk`

✅ Compatible avec 90%+ des téléphones modernes  
✅ Taille optimale (~20 MB)  
✅ Installation rapide

### Pour Distribution Large
**Utilisez** : `app-release.apk` (universel)

✅ Fonctionne sur tous les appareils  
⚠️ Plus gros (~40 MB)

### Pour Google Play Store
**Utilisez** : `app-release.aab`

✅ Format requis par Google Play  
✅ Google génère automatiquement les APKs optimisés

---

## ✅ CHECKLIST FINALE

Avant de distribuer l'APK :

- [ ] Build réussi sans erreurs
- [ ] APK généré dans `build/app/outputs/flutter-apk/`
- [ ] Taille de l'APK raisonnable (< 25 MB)
- [ ] Installation test sur un appareil réel
- [ ] Application démarre sans crash
- [ ] Navigation fonctionne (4 onglets)
- [ ] Connexion backend testée (51.15.89.72)
- [ ] Firebase configuré (google-services.json)
- [ ] Toutes les pages accessibles

---

## 🔗 RESSOURCES

### Liens Utiles

- **Repository GitHub** : https://github.com/emstronglezin-cmd/Omnisms-frontend
- **Branche** : feature/full-integration-v2
- **Documentation Flutter** : https://docs.flutter.dev/deployment/android
- **Guide Firebase** : https://firebase.google.com/docs/flutter/setup

### Fichiers Importants

```
Omnisms-frontend/
├── android/app/google-services.json  ← Firebase config
├── lib/config/api_config.dart        ← Backend URL
├── pubspec.yaml                      ← Version + dépendances
├── build_app.sh                      ← Script de build
└── BUILD_GUIDE.md                    ← Ce guide
```

---

## 🆘 SUPPORT

Si vous rencontrez des problèmes :

1. **Vérifiez les prérequis** (Flutter, Java, Android SDK)
2. **Lisez les erreurs** complètement
3. **Nettoyez** avec `flutter clean`
4. **Tentez avec le script** `build_app.sh`
5. **Consultez les logs** : `flutter build apk --release --verbose`

---

## 🎉 RÉSUMÉ

**Pour générer les builds** :

```bash
# Simple et rapide
git clone https://github.com/emstronglezin-cmd/Omnisms-frontend.git
cd Omnisms-frontend
git checkout feature/full-integration-v2
chmod +x build_app.sh
./build_app.sh
```

**Temps total** : 10-15 minutes  
**Fichiers obtenus** : APK + AAB prêts à installer/distribuer

---

**Version** : 2.1.0  
**Build** : 3  
**Date** : 2026-03-10  
**Status** : ✅ **READY TO BUILD**

🎊 **GUIDE COMPLET FOURNI !** 🎊
