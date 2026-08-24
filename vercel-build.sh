#!/bin/bash
# OmniSMS - Flutter Web PWA Build Script
# Compile l'application Flutter pour le web (build/web)
set -e

echo "🚀 OmniSMS Flutter Web Build"
echo "============================="

# ── Localiser ou installer Flutter ────────────────────────────
if command -v flutter >/dev/null 2>&1; then
  echo "✅ Flutter déjà présent : $(flutter --version | head -1)"
elif [ -d "$HOME/.flutter-sdk/bin" ]; then
  export PATH="$HOME/.flutter-sdk/bin:$PATH"
  echo "✅ Flutter SDK en cache : $(flutter --version | head -1)"
else
  echo "📦 Installation du Flutter SDK 3.44.9 (version du projet, shallow clone)..."
  git clone \
    https://github.com/flutter/flutter.git \
    -b 3.44.9 --depth 1 \
    "$HOME/.flutter-sdk"
  export PATH="$HOME/.flutter-sdk/bin:$PATH"
  echo "✅ Flutter installé : $(flutter --version | head -1)"
fi

# ── Build ──────────────────────────────────────────────────────
flutter config --enable-web --no-analytics >/dev/null 2>&1 || true
echo "📥 flutter pub get..."
flutter pub get
echo "🔨 flutter build web --release..."
flutter build web --release

echo ""
echo "✅ Build terminé — sortie : build/web/"
ls -lh build/web/ | head -20
