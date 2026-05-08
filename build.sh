#!/bin/bash

# 🚀 Netlify Build Script for OmniSMS Flutter Web PWA
# This script is automatically executed by Netlify during deployment

set -e

echo "🌐 OmniSMS - Netlify Build Script"
echo "=================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Flutter is installed
if [ ! -d "flutter" ]; then
    echo -e "${BLUE}📥 Installing Flutter SDK...${NC}"
    
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
    tar xf flutter_linux_3.24.5-stable.tar.xz
    rm flutter_linux_3.24.5-stable.tar.xz
    
    echo -e "${GREEN}✅ Flutter SDK installed${NC}"
else
    echo -e "${GREEN}✅ Flutter SDK already installed${NC}"
fi

# Add Flutter to PATH
export PATH="$PATH:$PWD/flutter/bin"

# Disable analytics
flutter config --no-analytics

# Verify Flutter
echo -e "${BLUE}🔍 Verifying Flutter installation...${NC}"
flutter --version

# Clean previous builds
echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean

# Get dependencies
echo -e "${BLUE}📦 Installing dependencies...${NC}"
flutter pub get

# Build for web
echo -e "${BLUE}🏗️  Building Flutter Web (release)...${NC}"
flutter build web \
  --release \
  --web-renderer html \
  --base-href "/"

echo -e "${GREEN}✅ Build completed successfully!${NC}"

# Show build info
echo ""
echo "📊 Build Information:"
echo "  - Flutter Version: $(flutter --version | head -n 1)"
echo "  - Build Directory: build/web"
echo "  - Build Size: $(du -sh build/web | cut -f1)"

echo ""
echo "📁 Generated Files:"
ls -lh build/web/*.html build/web/*.js 2>/dev/null || echo "  Files generated successfully"

echo ""
echo -e "${GREEN}🎉 Ready for deployment!${NC}"
