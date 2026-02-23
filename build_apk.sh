#!/bin/bash
set -e

export JAVA_HOME=/home/user/jdk-17.0.13+11
export ANDROID_HOME=/home/user/android-sdk
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/home/user/flutter/bin:$PATH

# Nettoyer
echo "Nettoyage..."
rm -rf build android/build android/.gradle ~/.gradle 2>/dev/null || true

# Récupérer les dépendances Flutter
echo "Récupération des dépendances..."
flutter pub get

# Générer le code nécessaire
echo "Génération du code Dart..."
flutter pub run build_runner build --delete-conflicting-outputs 2>/dev/null || true

# Construire via gradlew directement
echo "Construction APK..."
cd android
./gradlew assembleRelease --no-daemon --max-workers=1 --no-parallel --stacktrace || {
    echo "Échec avec stacktrace complète..."
    ./gradlew assembleRelease --no-daemon --max-workers=1 --no-parallel --stacktrace --debug 2>&1 | tail -500
    exit 1
}

echo "APK construit avec succès!"
ls -lh app/build/outputs/apk/release/
