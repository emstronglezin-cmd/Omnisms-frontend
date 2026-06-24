#!/bin/bash

# Vercel Build Script for OmniSMS Flutter Web PWA

set -e

echo "🌐 OmniSMS - Vercel Build Script"
echo "=================================="

# Fix Git ownership warnings (Vercel runs as root)
git config --global --add safe.directory '*'

# Check if Flutter is installed
if [ ! -d "flutter" ]; then
    echo "📥 Installing Flutter SDK (v3.44.3 stable)..."
    # Use latest stable version (3.44.3) to satisfy url_launcher ^6.3.1 requirements
    curl -sL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.3-stable.tar.xz -o flutter.tar.xz
    tar xf flutter.tar.xz
    rm flutter.tar.xz
    echo "✅ Flutter SDK installed"
else
    echo "✅ Flutter SDK already installed"
fi

# Add Flutter to PATH
export PATH="$PATH:$PWD/flutter/bin"

# Fix Flutter git ownership
git config --global --add safe.directory "$PWD/flutter"

# Disable analytics
flutter config --no-analytics 2>/dev/null || true

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
