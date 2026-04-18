# 📱 OmniSMS - Progressive Web App

> Application de messagerie SMS professionnelle moderne avec notifications push, mode offline et analytics

[![Flutter](https://img.shields.io/badge/Flutter-3.24.5-blue.svg)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Hosting-orange.svg)](https://firebase.google.com)
[![PWA](https://img.shields.io/badge/PWA-Ready-green.svg)](https://web.dev/progressive-web-apps)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

## 🌐 Live Demo

- **Production:** [https://omnisms-b98c5.web.app](https://omnisms-b98c5.web.app)
- **Backend API:** [https://omnismss-backend.onrender.com](https://omnismss-backend.onrender.com)

## ✨ Fonctionnalités

### Core
- 📱 **PWA Installable** - Installer comme app native
- 💬 **Messagerie SMS** - Envoi/réception de SMS
- 👥 **Gestion de Contacts** - Sync avec contacts du téléphone
- 👨‍👩‍👧‍👦 **Groupes** - Création et gestion de groupes
- 🎤 **Messages Vocaux** - Enregistrement et transcription
- 💳 **Abonnement** - Plan Premium à 2000 FCFA/mois

### Fonctionnalités Avancées
- 🔔 **Notifications Push Web** - Notifications en temps réel (FCM)
- 📴 **Mode Offline** - Fonctionne sans connexion internet
- 📊 **Analytics** - Tracking Google Analytics 4
- ⚡ **Lazy Loading** - Chargement optimisé
- 🌓 **Dark Mode** - Thème clair/sombre
- 🔐 **Authentification** - Firebase Auth
- 🔄 **Sync Auto** - Synchronisation automatique

## 🏗️ Architecture

### Frontend
```
lib/
├── layouts/          # Layouts responsive (mobile/web)
├── screens/          # Écrans de l'app
├── services/         # Services (API, FCM, Analytics, Offline)
├── providers/        # State management (Provider)
├── models/           # Modèles de données
└── widgets/          # Widgets réutilisables
```

### CI/CD
- **GitHub Actions** - Build & deploy automatique
- **Firebase Hosting** - Hébergement web
- **Lighthouse** - Audits de performance
- **Multi-browser** - Tests Chrome/Firefox

## 🚀 Quick Start

### Prérequis
- Flutter 3.24.5+
- Dart 3.4.0+
- Firebase CLI
- Node.js (pour Firebase)

### Installation

```bash
# Cloner le repo
git clone https://github.com/emstronglezin-cmd/Omnisms-frontend.git
cd Omnisms-frontend

# Installer les dépendances
flutter pub get

# Lancer en mode web
flutter run -d chrome

# Build pour production
flutter build web --release
```

### Déploiement

**Automatique (Recommandé):**
```bash
# Push vers main déclenche le build & deploy
git push origin main
```

**Manuel:**
```bash
flutter build web --release
firebase deploy --only hosting
```

## 📊 Stack Technique

### Frontend
- **Framework:** Flutter 3.24.5
- **State Management:** Provider
- **Storage:** SharedPreferences (IndexedDB sur web)
- **HTTP:** http package
- **WebSocket:** web_socket_channel

### Backend & Services
- **Backend:** Node.js/Express
- **Database:** MongoDB
- **Auth:** Firebase Auth
- **Notifications:** Firebase Cloud Messaging (FCM)
- **Analytics:** Google Analytics 4
- **Hosting:** Firebase Hosting
- **Monitoring:** Firebase Crashlytics

### DevOps
- **CI/CD:** GitHub Actions
- **Version Control:** Git/GitHub
- **Testing:** Flutter Test + Playwright
- **Performance:** Lighthouse CI

## 📚 Documentation

- **[COMPLETE_PWA_GUIDE.md](./COMPLETE_PWA_GUIDE.md)** - Guide complet PWA (13KB)
- **[GITHUB_SECRETS_SETUP.md](./GITHUB_SECRETS_SETUP.md)** - Configuration CI/CD
- **[FINAL_SUMMARY.md](./FINAL_SUMMARY.md)** - Résumé final
- **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)** - Référence rapide
- **[PWA_DOCUMENTATION.md](./PWA_DOCUMENTATION.md)** - Doc PWA

## 🔧 Configuration

### 1. Firebase Service Account (Obligatoire)

Pour activer le déploiement automatique via GitHub Actions:

```bash
firebase init hosting:github
```

Puis ajouter le secret dans GitHub:
- **Name:** `FIREBASE_SERVICE_ACCOUNT`
- **Value:** Contenu du JSON

[📖 Guide détaillé](./GITHUB_SECRETS_SETUP.md)

### 2. Google Analytics 4 (Optionnel)

Fichier: `lib/services/analytics_service.dart`
```dart
static const String _measurementId = 'G-XXXXXXXXXX';
```

### 3. FCM VAPID Key (Optionnel)

Fichier: `lib/services/web_notification_service.dart`
```dart
vapidKey: 'VOTRE-VAPID-KEY-ICI',
```

## 🎯 Objectifs de Performance

| Métrique | Cible | Actuel |
|----------|-------|--------|
| Performance | >90 | - |
| Accessibility | >95 | - |
| Best Practices | >95 | - |
| SEO | >90 | - |
| PWA Score | 100 | - |

## 🧪 Tests

### Unitaires
```bash
flutter test
```

### E2E (Playwright)
```bash
npm install -g playwright
playwright install
playwright test
```

### Performance (Lighthouse)
```bash
npm install -g lighthouse
lighthouse https://omnisms-b98c5.web.app --view
```

## 📱 Compatibilité

### Navigateurs
- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+

### Plateformes
- ✅ Web (Desktop)
- ✅ Web (Mobile)
- ✅ Android (via APK)
- ✅ iOS (via PWA)

## 🤝 Contribution

Ce projet est privé. Pour contribuer:
1. Fork le repo
2. Créer une branche (`git checkout -b feature/amazing-feature`)
3. Commit les changements (`git commit -m 'feat: Add amazing feature'`)
4. Push vers la branche (`git push origin feature/amazing-feature`)
5. Ouvrir une Pull Request

## 📄 License

Copyright © 2026 OmniSMS. Tous droits réservés.

## 👥 Équipe

- **Frontend:** Flutter/Dart
- **Backend:** Node.js/Express
- **DevOps:** GitHub Actions + Firebase

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/emstronglezin-cmd/Omnisms-frontend/issues)
- **Email:** support@omnisms.com (à configurer)
- **Documentation:** [Voir ci-dessus](#-documentation)

## 🔗 Liens Utiles

- **Firebase Console:** https://console.firebase.google.com/project/omnisms-b98c5
- **Google Analytics:** https://analytics.google.com
- **Backend API:** https://omnismss-backend.onrender.com
- **Abonnement:** https://www.pay.moneyfusion.net/abonnement-a-omnisms-_1762539771460/

## 📈 Roadmap

### Court Terme
- [x] PWA Complete
- [x] Notifications Push
- [x] Mode Offline
- [x] Analytics GA4
- [ ] Tests E2E complets
- [ ] Optimisation bundle size

### Moyen Terme
- [ ] Support multilingue (i18n)
- [ ] Thème personnalisable
- [ ] Export de conversations
- [ ] Recherche globale
- [ ] Appels voix/vidéo (WebRTC)

### Long Terme
- [ ] App mobile native (Android/iOS)
- [ ] Desktop app (Windows/Mac/Linux)
- [ ] Intégrations tierces
- [ ] API publique

## ⭐ Star History

Si ce projet vous aide, n'hésitez pas à lui donner une ⭐ !

---

**Version:** 2.2.0+4  
**Status:** ✅ Production Ready  
**Last Updated:** 2026-04-18  
**Made with ❤️ using Flutter**
