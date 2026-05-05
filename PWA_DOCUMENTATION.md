# 🌐 OmniSMS - Flutter Web PWA

## Vue d'ensemble

OmniSMS est maintenant disponible en tant que **Progressive Web App (PWA)** complète, offrant une expérience native sur le web avec toutes les fonctionnalités de l'application mobile.

## 🎯 Fonctionnalités PWA

### ✅ Implémentées

1. **Layout Responsive**
   - Mobile (<600px): Layout vertical classique avec navigation en bas
   - Tablet/Desktop (≥600px): Layout 2 colonnes avec sidebar et header
   - Adaptation automatique basée sur la largeur de l'écran

2. **Manifest PWA**
   - Nom: "OmniSMS - Messagerie SMS Professionnelle"
   - Couleurs du thème: #080c14 (dark mode)
   - Icônes 192x192 et 512x512
   - Mode standalone
   - Shortcuts vers Messages, Contacts, Groupes

3. **Service Worker**
   - Enregistrement automatique au chargement
   - Cache des ressources statiques
   - Fonctionnement offline de base

4. **Installation PWA**
   - Bouton d'installation automatique après 3 secondes
   - Détection du prompt beforeinstallprompt
   - Interface d'installation personnalisée

5. **Indicateur de connexion**
   - Détection online/offline en temps réel
   - Badge visuel dans le header
   - Gestion des états de connexion

6. **Interface Web**
   - Sidebar de navigation (Dashboard, Messages, Contacts, Groupes, Stats, Abonnement)
   - Header avec infos utilisateur et statut Premium
   - Dashboard adapté au web avec 4 cartes de statistiques
   - Bouton de déconnexion
   - Design cohérent avec les couleurs de la marque

## 🎨 Design System

### Couleurs
- **Background**: `#080c14`
- **Surface**: `#0f1520`
- **Accent primaire**: `#00d4ff`
- **Accent secondaire**: `#0066ff`
- **Texte**: `#e8edf5`
- **Texte muté**: `#6b7a96`

### Typographie
- Titres: Font weight 700
- Sous-titres: Font weight 600
- Corps: Font weight 400

## 📱 Écrans Adaptés

### Dashboard (Web)
- 4 cartes de statistiques en ligne
- Bannière d'abonnement Premium
- Actions rapides avec navigation
- Badge de statut d'abonnement

### Messages (Web)
- Layout liste-détail
- Panneau de composition
- Recherche de contacts

### Contacts (Web)
- Liste avec recherche
- Bouton d'ajout rapide
- Tri et filtres

### Groupes (Web)
- Création de groupes
- Gestion des membres
- Liste des groupes

## 🚀 Build et Déploiement

### Prérequis
```bash
flutter doctor
firebase login
```

### Build pour le Web
```bash
cd /home/user/webapp
flutter clean
flutter pub get
flutter build web --release
```

Le build génère les fichiers dans `build/web/`.

### Déploiement Firebase
```bash
firebase deploy --only hosting
```

L'application sera déployée sur: `https://omnisms-b98c5.web.app`

### Configuration Firebase
- **Project ID**: omnisms-b98c5
- **Public directory**: build/web
- **Rewrites**: toutes les routes vers /index.html (SPA)
- **Headers**: cache 1 an pour assets, sécurité renforcée

## 🔧 Configuration Technique

### web/manifest.json
```json
{
  "name": "OmniSMS - Messagerie SMS Professionnelle",
  "short_name": "OmniSMS",
  "theme_color": "#080c14",
  "background_color": "#080c14",
  "display": "standalone"
}
```

### web/index.html
- Meta tags pour iOS et Android
- Open Graph pour partage social
- Service worker registration
- Loading splash screen animé
- PWA install prompt
- Offline indicator

### Architecture
```
lib/
├── layouts/
│   ├── responsive_layout.dart      # Widget responsive principal
│   ├── web_sidebar.dart           # Sidebar de navigation web
│   └── web_main_layout.dart       # Layout principal web
├── screens/
│   ├── dashboard_screen.dart      # Dashboard adapté web/mobile
│   ├── auth/
│   ├── contacts/
│   ├── groups/
│   ├── messaging/
│   └── settings/
├── providers/                     # State management (inchangé)
├── services/                      # API services (inchangé)
└── main.dart                      # Entry point avec routes
```

## 📊 Statistiques Dashboard Web

- **Crédits SMS**: Affichage du solde
- **Envoyés**: Nombre de SMS envoyés
- **Contacts**: Total des contacts
- **Groupes**: Nombre de groupes

Chaque carte affiche:
- Icône colorée
- Valeur en grand
- Label descriptif
- Badge de tendance (+/- %)

## 🔐 Backend Integration

- **Base URL**: https://omnisms-backend.onrender.com
- **WebSocket**: wss://omnisms-backend.onrender.com/ws
- **Timeout**: 30 secondes
- **Auth**: JWT via SharedPreferences
- Services inchangés (réutilisation du code mobile)

## 🌍 Support Offline

1. **Cache**:
   - Ressources statiques (JS, CSS, images)
   - Page index.html
   - Assets Flutter

2. **Données**:
   - Contacts récents via SharedPreferences
   - Messages en cache
   - État d'authentification

3. **Indicateur**:
   - Badge rouge "Mode hors ligne"
   - Mise à jour automatique du statut

## 📈 Prochaines Étapes

- [ ] Tests end-to-end sur différents navigateurs
- [ ] Optimisation des performances (lazy loading)
- [ ] Notifications push web (Firebase Cloud Messaging)
- [ ] Mode offline avancé avec IndexedDB
- [ ] Analytics (Google Analytics 4)
- [ ] Tests A/B pour l'onboarding
- [ ] Support multilingue (i18n)
- [ ] Thème clair/sombre dynamique
- [ ] Export de conversations
- [ ] Recherche globale

## 🐛 Debugging

### Tester localement
```bash
flutter run -d chrome
```

### Tester le build
```bash
cd build/web
python3 -m http.server 8000
```
Ouvrir: http://localhost:8000

### Vérifier le Service Worker
1. Ouvrir DevTools (F12)
2. Aller dans l'onglet "Application"
3. Section "Service Workers"
4. Vérifier que flutter_service_worker.js est activé

### Tester l'installation PWA
1. Ouvrir en navigation privée
2. Attendre 3 secondes
3. Cliquer sur "Installer"
4. Vérifier l'icône sur le bureau/home screen

## 📝 Notes de Version

### Version 2.2.0-web.1
- ✅ Layout responsive complet
- ✅ Manifest PWA configuré
- ✅ Service worker enregistré
- ✅ Bouton d'installation PWA
- ✅ Offline indicator
- ✅ Dashboard adapté au web
- ✅ Firebase hosting configuré
- ✅ Backend integration préservée
- ✅ Design system appliqué

## 📞 Support

Pour toute question ou problème:
- Backend: https://omnisms-backend.onrender.com
- Abonnement: https://www.pay.moneyfusion.net/abonnement-a-omnisms-_1762539771460/
- Email: support@omnisms.com (à configurer)

---

**Statut**: ✅ Production Ready
**Date**: 2026-04-14
**Version**: 2.2.0-web.1
