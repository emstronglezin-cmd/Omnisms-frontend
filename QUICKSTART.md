# 🚀 Guide de Démarrage Rapide - OmniSMS

## 📱 À Propos

OmniSMS est une application mobile moderne de messagerie avec une interface utilisateur élégante, des animations fluides et une intégration backend complète.

## ✨ Fonctionnalités

- 💬 **Messagerie en temps réel** avec WebSocket
- 👥 **Gestion de contacts** avec recherche
- 🎨 **Interface moderne** Material Design 3
- 🌓 **Thème clair/sombre** automatique
- ✨ **Animations fluides** sur tous les écrans
- 🔗 **Tests de connexion** backend intégrés
- 🎙️ **Transcription audio** (à venir)
- 👥 **Groupes de discussion** (à venir)

## 🛠️ Prérequis

- Flutter SDK (stable channel)
- Dart SDK ≥ 3.4.0
- Android SDK avec API 23+ (Android 6.0+)
- Java JDK 11+

## 📥 Installation

1. **Cloner le repository**
   ```bash
   git clone https://github.com/emstronglezin-cmd/Omnisms-frontend.git
   cd Omnisms-frontend
   ```

2. **Installer les dépendances**
   ```bash
   flutter pub get
   ```

3. **Vérifier la configuration**
   ```bash
   flutter doctor
   ```

## 🏃 Lancer l'Application

### Mode Debug

```bash
flutter run
```

### Mode Release

```bash
flutter run --release
```

## 🔨 Générer les Builds

### Option 1: Script Automatique (Recommandé)

```bash
./build.sh
```

Le script vous guidera à travers les options de build.

### Option 2: Commandes Manuelles

**APK Standard**
```bash
flutter build apk --release
```

**APK Optimisé (Recommandé)**
```bash
flutter build apk --split-per-abi --release --obfuscate --split-debug-info=build/debug-info
```

**AAB pour Play Store**
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
```

## 🎨 Nouveautés de l'Interface

### Écran d'Accueil
- Navigation par onglets moderne
- Statistiques en temps réel
- Actions rapides
- Liste de fonctionnalités

### Écran des Contacts
- Barre de recherche en temps réel
- Avatars colorés uniques
- Animations d'entrée échelonnées
- Design de cartes moderne

### Écran de Conversation
- Bulles de messages avec gradients
- Animations fluides
- Barre d'actions (appels vidéo/audio)
- Menu de pièces jointes

### Tests de Connexion
- Interface visuelle des tests
- Mesure de performance
- Feedback en temps réel

## 🔧 Configuration

### Backend

Le backend est configuré dans `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'http://51.15.89.72';
static const String wsUrl = 'ws://51.15.89.72/ws';
```

Pour tester la connexion backend:
1. Lancez l'application
2. Allez dans l'écran Contacts
3. Appuyez sur l'icône réseau (🌐)
4. Lancez les tests

### Keystore (Pour Builds Signés)

Le keystore est configuré dans `android/key.properties`:
- Store Password: `omnisms2026`
- Key Alias: `omnisms-key`
- Fichier: `android/omnisms-keystore.jks`

## 📦 Dépendances Principales

```yaml
# Core
flutter: SDK
cupertino_icons: ^1.0.8

# Firebase
firebase_core: ^3.15.2
firebase_auth: ^5.7.0
firebase_messaging: ^15.2.10

# UI/UX
flutter_animate: ^4.5.0
google_fonts: ^6.2.1
flutter_staggered_animations: ^1.1.1

# Networking
http: ^1.6.0
web_socket_channel: ^3.0.3

# State Management
provider: ^6.1.5+1
```

## 🎯 Architecture

```
lib/
├── config/
│   ├── api_config.dart       # Configuration API
│   └── app_theme.dart        # Thème de l'application
├── screens/
│   ├── connection_test_screen.dart
│   ├── groups_screen.dart
│   ├── subscription_screen.dart
│   └── transcription_screen.dart
├── services/
│   ├── api_service.dart
│   ├── connection_test_service.dart
│   └── transcription_service.dart
├── ui/
│   └── home_screen.dart      # Écran principal
├── contacts_creen.dart       # Écran des contacts
├── conversation_screen.dart  # Écran de conversation
├── contacts_provider.dart    # Provider contacts
├── conversation_provider.dart # Provider conversation
└── main.dart                 # Point d'entrée
```

## 🧪 Tests

### Tests Unitaires
```bash
flutter test
```

### Tests d'Intégration
```bash
flutter test integration_test
```

## 📱 Compatibilité

- **Android**: 6.0+ (API 23+)
- **Taille APK**: ~20-25 MB (arm64)
- **Taille AAB**: ~35-50 MB

## 🐛 Résolution de Problèmes

### Erreur: "Flutter not found"
```bash
export PATH="$PATH:/path/to/flutter/bin"
```

### Erreur: "Gradle build failed"
```bash
flutter clean
cd android && ./gradlew clean
cd .. && flutter pub get
```

### Erreur: "Backend non accessible"
1. Vérifiez que le backend est démarré
2. Utilisez l'écran de test de connexion
3. Vérifiez l'URL dans `api_config.dart`

## 📚 Documentation

- [UI_IMPROVEMENTS.md](UI_IMPROVEMENTS.md) - Détails des améliorations UI
- [BUILD_GUIDE.md](BUILD_GUIDE.md) - Guide complet de build
- [BACKEND_SETUP.md](BACKEND_SETUP.md) - Configuration backend
- [SUMMARY.md](SUMMARY.md) - Récapitulatif complet

## 🤝 Contribution

1. Fork le projet
2. Créez une branche (`git checkout -b feature/AmazingFeature`)
3. Commitez vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## 📄 Licence

Ce projet est sous licence propriétaire. Tous droits réservés.

## 📞 Support

Pour toute question ou problème:
- Ouvrez une issue sur GitHub
- Consultez la documentation dans le dossier `docs/`
- Contactez l'équipe de développement

## 🎉 Changelog

### Version 1.0.0 (21 février 2026)

#### Ajouté
- Interface moderne Material Design 3
- Système de thème clair/sombre
- Animations fluides avec flutter_animate
- Écran d'accueil avec navigation par onglets
- Recherche de contacts en temps réel
- Avatars colorés uniques
- Tests de connexion backend intégrés
- Documentation complète

#### Modifié
- Configuration Android optimisée
- Application ID: `com.omnisms.app`
- Target SDK: 34 (Android 14)
- Build avec ProGuard activé

#### Technique
- MultiDex activé
- Obfuscation configurée
- Signing automatique
- Optimisations de performance

---

**Version**: 1.0.0  
**Status**: ✅ Production Ready  
**Date**: 21 février 2026
