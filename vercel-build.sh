#!/bin/bash

# Vercel Build Script for OmniSMS Flutter Web PWA
set -e

echo "🌐 OmniSMS - Vercel Build Script"
echo "=================================="

# Fix Git ownership warnings (Vercel runs as root)
git config --global --add safe.directory '*' 2>/dev/null || true

# ── FLUTTER INSTALLATION ─────────────────────────────────────────────────────
FLUTTER_VERSION="3.44.3"
FLUTTER_DIR="$PWD/flutter"

if [ ! -f "$FLUTTER_DIR/bin/flutter" ]; then
  echo "📥 Installing Flutter SDK (v${FLUTTER_VERSION} stable)..."
  FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  curl -sL "$FLUTTER_URL" -o flutter.tar.xz
  echo "📦 Extracting Flutter..."
  tar xf flutter.tar.xz
  rm flutter.tar.xz
  echo "✅ Flutter SDK installed"
else
  echo "✅ Flutter SDK already present"
fi

# Add Flutter to PATH
export PATH="$PATH:$FLUTTER_DIR/bin"

# Fix Flutter git ownership
git config --global --add safe.directory "$FLUTTER_DIR" 2>/dev/null || true

# Disable analytics & telemetry
flutter config --no-analytics 2>/dev/null || true

# ── VERIFY FLUTTER ────────────────────────────────────────────────────────────
echo "🔍 Verifying Flutter installation..."
flutter --version

# ── DEPENDENCIES ─────────────────────────────────────────────────────────────
echo "🧹 Cleaning previous builds..."
flutter clean

echo "📦 Installing dependencies..."
# Remove stale lock file if it exists (prevent conflicts)
rm -f pubspec.lock
flutter pub get

# ── BUILD ─────────────────────────────────────────────────────────────────────
echo "🏗️  Building Flutter Web (release)..."
flutter build web \
  --release \
  --base-href "/"

echo "✅ Build completed successfully!"

# ── BUILD INFO ────────────────────────────────────────────────────────────────
echo ""
echo "📊 Build Information:"
echo "  - Flutter Version: $(flutter --version | head -n 1)"
echo "  - Build Directory: build/web"
echo "  - Output files:"
ls -la build/web/
echo "  - Build Size: $(du -sh build/web | cut -f1)"

echo ""
echo "🎉 Ready for deployment on Vercel!"
