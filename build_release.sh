#!/bin/bash
# Utility script to produce release APK and AAB for the Omnisms Flutter app.
# Run this on a machine that has the Flutter SDK installed and configured.

set -e

echo "Cleaning previous builds..."
flutter clean

echo "Resolving dependencies..."
flutter pub get

echo "Building release APK..."
flutter build apk --release

echo "Building release App Bundle (AAB)..."
flutter build appbundle --release

echo "Done. Artifacts are located in build/app/outputs/ (apk & bundle)."