#!/bin/bash

# 🚀 Script de Build Automatisé - OmniSMS v2.1.0
# Ce script automatise le processus de build APK/AAB

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage
print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Banner
clear
print_header "🚀 OmniSMS v2.1.0 - Build Automatisé"

# 1. Vérification de l'environnement
print_header "1️⃣ Vérification de l'environnement"

# Vérifier Flutter
if ! command -v flutter &> /dev/null; then
    print_error "Flutter n'est pas installé ou pas dans le PATH"
    print_info "Téléchargez Flutter depuis: https://flutter.dev/docs/get-started/install"
    exit 1
fi
print_success "Flutter installé: $(flutter --version | head -n 1)"

# Vérifier Java
if ! command -v java &> /dev/null; then
    print_error "Java n'est pas installé"
    print_info "Installez Java JDK 17: https://adoptium.net"
    exit 1
fi
JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
if [ "$JAVA_VERSION" != "17" ]; then
    print_warning "Java version $JAVA_VERSION détectée (recommandé: 17)"
else
    print_success "Java 17 installé"
fi

# Vérifier Android SDK
if [ -z "$ANDROID_HOME" ]; then
    print_warning "ANDROID_HOME n'est pas défini"
    print_info "Définissez-le dans votre fichier ~/.bashrc ou ~/.zshrc"
else
    print_success "Android SDK: $ANDROID_HOME"
fi

# 2. Vérification du repository
print_header "2️⃣ Vérification du repository"

# Vérifier qu'on est dans le bon dossier
if [ ! -f "pubspec.yaml" ]; then
    print_error "Fichier pubspec.yaml non trouvé"
    print_info "Assurez-vous d'être dans le dossier racine du projet"
    exit 1
fi
print_success "Dossier du projet trouvé"

# Vérifier la branche Git
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
if [ "$CURRENT_BRANCH" != "feature/full-integration-v2" ]; then
    print_warning "Branche actuelle: $CURRENT_BRANCH (recommandé: feature/full-integration-v2)"
    read -p "Voulez-vous changer de branche? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git checkout feature/full-integration-v2
        print_success "Branche changée"
    fi
else
    print_success "Branche: $CURRENT_BRANCH"
fi

# Vérifier la version
APP_VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
print_success "Version de l'app: $APP_VERSION"

# 3. Nettoyage et préparation
print_header "3️⃣ Nettoyage et préparation"

print_info "Nettoyage des fichiers temporaires..."
flutter clean
print_success "Nettoyage terminé"

print_info "Téléchargement des dépendances..."
flutter pub get
print_success "Dépendances installées"

# 4. Vérification de la configuration
print_header "4️⃣ Vérification de la configuration"

# Vérifier google-services.json
if [ -f "android/app/google-services.json" ]; then
    print_success "Firebase configuré (google-services.json trouvé)"
else
    print_error "google-services.json manquant"
    print_info "Copiez votre fichier Firebase dans android/app/"
fi

# Vérifier le keystore
if [ -f "android/omnisms-keystore.jks" ]; then
    print_success "Keystore trouvé (android/omnisms-keystore.jks)"
else
    print_warning "Keystore non trouvé (l'APK sera en mode debug)"
    print_info "Pour créer un keystore: keytool -genkey -v -keystore android/omnisms-keystore.jks -alias omnisms-key -keyalg RSA -keysize 2048 -validity 10000"
fi

# Vérifier la configuration backend
if grep -q "51.15.89.72" lib/config/api_config.dart; then
    print_success "Backend configuré (51.15.89.72:5000)"
else
    print_warning "Backend non configuré dans api_config.dart"
fi

# 5. Menu de build
print_header "5️⃣ Sélection du type de build"

echo "Choisissez le type de build:"
echo "  1) APK ARM64 uniquement (recommandé, ~20 MB)"
echo "  2) APK splitté par architecture (3 fichiers, ~18-22 MB chacun)"
echo "  3) APK universel (tous appareils, ~60 MB)"
echo "  4) AAB pour Play Store (~25 MB)"
echo "  5) Tous les types de build"
echo "  6) Annuler"
echo

read -p "Votre choix (1-6): " BUILD_CHOICE

case $BUILD_CHOICE in
    1)
        BUILD_TYPE="apk_arm64"
        BUILD_NAME="APK ARM64"
        ;;
    2)
        BUILD_TYPE="apk_split"
        BUILD_NAME="APK Splitté"
        ;;
    3)
        BUILD_TYPE="apk_universal"
        BUILD_NAME="APK Universel"
        ;;
    4)
        BUILD_TYPE="aab"
        BUILD_NAME="AAB Play Store"
        ;;
    5)
        BUILD_TYPE="all"
        BUILD_NAME="Tous les types"
        ;;
    6)
        print_info "Build annulé"
        exit 0
        ;;
    *)
        print_error "Choix invalide"
        exit 1
        ;;
esac

# 6. Lancement du build
print_header "6️⃣ Build de l'application - $BUILD_NAME"

# Fonction de build avec gestion d'erreur
build_with_retry() {
    local cmd=$1
    local name=$2
    local max_attempts=2
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        print_info "Tentative $attempt/$max_attempts pour $name..."
        
        if eval "$cmd"; then
            print_success "$name réussi"
            return 0
        else
            print_warning "$name échoué (tentative $attempt/$max_attempts)"
            
            if [ $attempt -lt $max_attempts ]; then
                print_info "Nettoyage et nouvelle tentative..."
                flutter clean > /dev/null 2>&1
                flutter pub get > /dev/null 2>&1
                sleep 2
            fi
            
            attempt=$((attempt + 1))
        fi
    done
    
    print_error "$name a échoué après $max_attempts tentatives"
    return 1
}

# Exécuter le build selon le choix
case $BUILD_TYPE in
    "apk_arm64")
        build_with_retry "flutter build apk --release --target-platform android-arm64" "APK ARM64"
        ;;
    "apk_split")
        build_with_retry "flutter build apk --release --split-per-abi" "APK Splitté"
        ;;
    "apk_universal")
        build_with_retry "flutter build apk --release" "APK Universel"
        ;;
    "aab")
        build_with_retry "flutter build appbundle --release" "AAB"
        ;;
    "all")
        print_info "Build de tous les types (cela peut prendre 10-20 minutes)..."
        
        build_with_retry "flutter build apk --release --target-platform android-arm64" "APK ARM64"
        build_with_retry "flutter build apk --release --split-per-abi" "APK Splitté"
        build_with_retry "flutter build appbundle --release" "AAB"
        ;;
esac

# 7. Résumé des fichiers générés
print_header "7️⃣ Fichiers générés"

OUTPUT_DIR="build/app/outputs"

if [ -d "$OUTPUT_DIR/flutter-apk" ]; then
    print_success "APKs générés:"
    find "$OUTPUT_DIR/flutter-apk" -name "*.apk" -exec sh -c 'echo "  📦 {} ($(du -h {} | cut -f1))"' \;
fi

if [ -d "$OUTPUT_DIR/bundle/release" ]; then
    print_success "AAB généré:"
    find "$OUTPUT_DIR/bundle/release" -name "*.aab" -exec sh -c 'echo "  📦 {} ($(du -h {} | cut -f1))"' \;
fi

# 8. Instructions d'installation
print_header "8️⃣ Prochaines étapes"

echo "Pour installer l'APK sur votre téléphone:"
echo ""
echo "1️⃣ Via câble USB:"
echo "   adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
echo ""
echo "2️⃣ Via transfert de fichier:"
echo "   - Copiez l'APK sur votre téléphone"
echo "   - Ouvrez-le avec le gestionnaire de fichiers"
echo "   - Autorisez l'installation depuis des sources inconnues"
echo ""
echo "3️⃣ Pour uploader sur le Play Store:"
echo "   - Connectez-vous à Google Play Console"
echo "   - Créez une nouvelle release"
echo "   - Uploadez le fichier app-release.aab"
echo ""

# 9. Vérification de la signature
if [ -f "android/omnisms-keystore.jks" ]; then
    print_header "9️⃣ Vérification de la signature"
    
    APK_FILE=$(find "$OUTPUT_DIR/flutter-apk" -name "app-*-release.apk" | head -n 1)
    if [ -n "$APK_FILE" ]; then
        print_info "Vérification de la signature de l'APK..."
        if jarsigner -verify -verbose -certs "$APK_FILE" 2>&1 | grep -q "jar verified"; then
            print_success "APK correctement signé"
        else
            print_warning "APK non signé ou signature invalide"
        fi
    fi
fi

# 10. Conclusion
print_header "✅ Build terminé avec succès !"

echo "📊 Résumé:"
echo "  • Version: $APP_VERSION"
echo "  • Branche: $CURRENT_BRANCH"
echo "  • Type de build: $BUILD_NAME"
echo "  • Backend: http://51.15.89.72:5000"
echo "  • Firebase: omnisms-b98c5"
echo ""
echo "📂 Dossier de sortie: $OUTPUT_DIR"
echo ""
echo "🎯 L'application est prête à être testée ou déployée !"
echo ""

# Demander si on doit ouvrir le dossier de sortie
if command -v open &> /dev/null; then
    read -p "Voulez-vous ouvrir le dossier de sortie? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "$OUTPUT_DIR"
    fi
elif command -v xdg-open &> /dev/null; then
    read -p "Voulez-vous ouvrir le dossier de sortie? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xdg-open "$OUTPUT_DIR"
    fi
fi

print_success "Script terminé"
