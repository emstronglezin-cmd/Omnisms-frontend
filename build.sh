#!/bin/bash

# Script de build automatique pour OmniSMS
# Ce script génère les fichiers APK et AAB optimisés

set -e  # Arrêter en cas d'erreur

echo "🏗️  Build OmniSMS - APK & AAB"
echo "================================"
echo ""

# Couleurs pour le terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Vérifier que Flutter est installé
if ! command -v flutter &> /dev/null; then
    log_error "Flutter n'est pas installé ou pas dans le PATH"
    log_info "Installez Flutter depuis: https://flutter.dev/docs/get-started/install"
    exit 1
fi

log_success "Flutter trouvé: $(flutter --version | head -n 1)"
echo ""

# Nettoyer les anciens builds
log_info "Nettoyage des anciens builds..."
flutter clean
log_success "Nettoyage terminé"
echo ""

# Installer les dépendances
log_info "Installation des dépendances..."
flutter pub get
log_success "Dépendances installées"
echo ""

# Vérifier la configuration
log_info "Vérification de la configuration..."
flutter doctor
echo ""

# Demander quel type de build
echo "Quel type de build voulez-vous générer?"
echo "1) APK Release (standard)"
echo "2) APK Release (split per ABI - recommandé)"
echo "3) AAB Release (Google Play Store)"
echo "4) Tous les types"
echo ""
read -p "Votre choix (1-4): " choice

case $choice in
    1)
        log_info "Génération de l'APK standard..."
        flutter build apk --release --obfuscate --split-debug-info=build/debug-info
        log_success "APK standard généré!"
        log_info "Emplacement: build/app/outputs/flutter-apk/app-release.apk"
        ;;
    2)
        log_info "Génération des APK par ABI..."
        flutter build apk --split-per-abi --release --obfuscate --split-debug-info=build/debug-info
        log_success "APK par ABI générés!"
        log_info "Emplacements:"
        log_info "  - build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
        log_info "  - build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
        log_info "  - build/app/outputs/flutter-apk/app-x86_64-release.apk"
        ;;
    3)
        log_info "Génération de l'AAB..."
        flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
        log_success "AAB généré!"
        log_info "Emplacement: build/app/outputs/bundle/release/app-release.aab"
        ;;
    4)
        log_info "Génération de tous les types..."
        
        log_info "1/2 - Génération des APK par ABI..."
        flutter build apk --split-per-abi --release --obfuscate --split-debug-info=build/debug-info
        log_success "APK générés!"
        
        log_info "2/2 - Génération de l'AAB..."
        flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
        log_success "AAB généré!"
        
        echo ""
        log_success "Tous les builds sont terminés!"
        log_info "Emplacements:"
        log_info "  APK: build/app/outputs/flutter-apk/"
        log_info "  AAB: build/app/outputs/bundle/release/"
        ;;
    *)
        log_error "Choix invalide"
        exit 1
        ;;
esac

echo ""
echo "================================"
log_success "Build terminé avec succès! 🎉"
echo ""

# Afficher les tailles des fichiers
if [ -d "build/app/outputs/flutter-apk" ]; then
    log_info "Tailles des fichiers APK:"
    ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null | awk '{print "  -", $9, ":", $5}' || true
fi

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    log_info "Taille du fichier AAB:"
    ls -lh build/app/outputs/bundle/release/app-release.aab | awk '{print "  -", $9, ":", $5}'
fi

echo ""
log_warning "N'oubliez pas de tester les builds sur un appareil réel!"
echo ""
