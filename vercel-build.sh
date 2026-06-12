#!/bin/bash

# Vercel Build Script for OmniSMS Flutter Web PWA

set -e

echo "🌐 OmniSMS - Vercel Build Script"
echo "=================================="

# Check if Flutter is installed
if [ ! -d "flutter" ]; then
    echo "📥 Installing Flutter SDK..."
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
    tar xf flutter_linux_3.24.5-stable.tar.xz
    rm flutter_linux_3.24.5-stable.tar.xz
    echo "✅ Flutter SDK installed"
else
    echo "✅ Flutter SDK already installed"
fi

# Add Flutter to PATH
export PATH="$PATH:$PWD/flutter/bin"

# Disable analytics
flutter config --no-analytics

# Verify Flutter
echo "🔍 Verifying Flutter installation..."
flutter --version

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Build for web
echo "🏗️  Building Flutter Web (release)..."
flutter build web \
  --release \
  --web-renderer html \
  --base-href "/"

echo "✅ Build completed successfully!"

# Show build info
echo ""
echo "📊 Build Information:"
echo "  - Flutter Version: $(flutter --version | head -n 1)"
echo "  - Build Directory: build/web"
echo "  - Build Size: $(du -sh build/web | cut -f1)"

echo ""
echo "🎉 Ready for deployment on Vercel!"
