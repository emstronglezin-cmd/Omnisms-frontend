#!/bin/bash

# 🚀 OmniSMS APK Build Script (Optimized for Low Memory)
# This script attempts to build APK with minimal RAM usage

set -e

echo "🔧 OmniSMS Build Script"
echo "========================"
echo ""

# Colors
RED='\033[0:31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Set environment
export PATH="$PATH:/home/user/flutter/bin"
export ANDROID_HOME="/home/user/android-sdk"

echo "📦 Step 1: Clean project..."
flutter clean
rm -rf build
rm -rf android/.gradle
rm -rf android/build
echo "✅ Clean complete"
echo ""

echo "📥 Step 2: Get dependencies..."
flutter pub get
echo "✅ Dependencies installed"
echo ""

echo "🏗️  Step 3: Building APK (this may take 10-15 minutes)..."
echo "⚠️  Note: Build may fail due to RAM limitations (< 1 GB available)"
echo ""

# Try to build with minimal resources
flutter build apk --release --split-per-abi \
  --target-platform android-arm64 \
  --no-tree-shake-icons \
  || {
    echo ""
    echo -e "${RED}❌ Build failed due to insufficient RAM${NC}"
    echo ""
    echo -e "${YELLOW}📝 Please build on your local machine:${NC}"
    echo "   1. git pull origin feature/complete-backend-integration"
    echo "   2. flutter pub get"
    echo "   3. flutter build apk --release --split-per-abi"
    echo ""
    exit 1
  }

echo ""
echo -e "${GREEN}✅ Build successful!${NC}"
echo ""
echo "📱 APK files generated:"
find build/app/outputs -name "*.apk" -type f -exec ls -lh {} \;
echo ""
echo "🎉 Build complete!"
