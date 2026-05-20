# 🚀 Guide de Déploiement OmniSMS

## ✅ Checklist Pré-Déploiement

### 1. Configuration Backend
- [ ] Vérifier que le backend est accessible: https://omnisms-backend.onrender.com
- [ ] Tester les endpoints dans `lib/config/api_config.dart`
- [ ] Vérifier la connexion WebSocket: wss://omnisms-backend.onrender.com/ws

### 2. Configuration PropellerAds
- [ ] Créer un compte sur https://propellerads.com/
- [ ] Créer les zones publicitaires (Banner, Interstitial, Push, Onclick)
- [ ] Copier les Zone IDs dans `lib/config/ads_config.dart`
- [ ] Activer le mode test pour vérifier l'affichage
- [ ] Remplacer `REPLACE_WITH_YOUR_BANNER_ZONE_ID` par les vrais IDs

### 3. Vérification du Code
```bash
# Nettoyer le projet
flutter clean

# Récupérer les dépendances
flutter pub get

# Analyser le code (vérifier les erreurs)
flutter analyze --no-fatal-infos

# Formater le code
flutter format lib/

# Tester l'application (si tests disponibles)
flutter test
```

### 4. Build pour le Web
```bash
# Build optimisé pour production
flutter build web --release --web-renderer canvaskit

# Ou avec HTML renderer (plus léger, moins de features)
flutter build web --release --web-renderer html

# Build avec désactivation des ads (développement)
flutter build web --release --dart-define=ADS_ENABLED=false
```

## 📦 Structure des Fichiers Construits

Après `flutter build web`, le dossier `build/web/` contient:
```
build/web/
├── index.html              # Point d'entrée
├── main.dart.js            # Code Dart compilé en JS
├── flutter_service_worker.js  # Service Worker PWA
├── manifest.json           # Manifeste PWA
├── icons/                  # Icônes de l'app
├── assets/                 # Assets (images, fonts)
└── canvaskit/             # Moteur de rendu (si canvaskit)
```

## 🌐 Déploiement sur Netlify

### Option 1: Déploiement Automatique (Recommandé)

1. **Configurer netlify.toml** (déjà fait):
```toml
[build]
  publish = "build/web"
  command = "flutter build web --release"

[build.environment]
  FLUTTER_VERSION = "3.24.0"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

2. **Push sur GitHub**:
```bash
git add .
git commit -m "feat: Complete modern UI, voice messages, and PropellerAds integration"
git push origin main
```

3. **Netlify Auto-Deploy**:
   - Netlify détecte automatiquement le push
   - Lance `flutter build web --release`
   - Déploie le contenu de `build/web/`
   - URL: https://omnisms.netlify.app (ou votre custom domain)

### Option 2: Déploiement Manuel

1. **Build localement**:
```bash
flutter build web --release
```

2. **Déployer via Netlify CLI**:
```bash
# Installer Netlify CLI
npm install -g netlify-cli

# Se connecter
netlify login

# Déployer
netlify deploy --prod --dir=build/web
```

3. **Ou via l'interface Netlify**:
   - Aller sur https://app.netlify.com
   - Glisser-déposer le dossier `build/web/`

## ✅ Vérifications Post-Déploiement

### 1. Fonctionnalités de Base
- [ ] L'application se charge correctement
- [ ] La page de connexion fonctionne (Firebase Auth)
- [ ] Le Dashboard s'affiche
- [ ] Les contacts se chargent
- [ ] Les groupes sont accessibles

### 2. Interface Moderne de Chat
- [ ] Les bulles de messages s'affichent correctement (style Instagram)
- [ ] Le typing indicator apparaît
- [ ] L'indicateur de statut en ligne fonctionne
- [ ] Les réactions emoji s'affichent
- [ ] Le timestamp des messages est correct
- [ ] Les messages lus/non lus sont indiqués

### 3. Messages Vocaux
- [ ] Le bouton micro apparaît dans l'input
- [ ] L'enregistrement démarre au clic
- [ ] La waveform s'affiche pendant l'enregistrement
- [ ] Le timer fonctionne (MM:SS)
- [ ] L'envoi du message vocal réussit
- [ ] Le player audio s'affiche pour les messages vocaux reçus
- [ ] La waveform de lecture fonctionne
- [ ] Les contrôles de vitesse (x1, x1.5, x2) fonctionnent
- [ ] La barre de progression est interactive

### 4. Transcription
- [ ] L'option "Transcrire" apparaît au long press sur message vocal
- [ ] Le loading s'affiche pendant la transcription
- [ ] La transcription s'affiche sous le message audio
- [ ] Le widget de transcription est stylé correctement

### 5. Performance
- [ ] Les images se chargent rapidement (cache)
- [ ] Le scroll est fluide (60 FPS)
- [ ] Pas de lag lors de l'envoi de messages
- [ ] La pagination fonctionne (charger plus de messages)
- [ ] Les animations sont smooth

### 6. PropellerAds
- [ ] Les bannières s'affichent (si Zone IDs configurés)
- [ ] Les ads ne bloquent pas l'UX
- [ ] Pas d'erreurs dans la console liées aux ads
- [ ] Les clicks sur les ads fonctionnent

### 7. PWA
- [ ] L'icône "Installer" apparaît dans le navigateur
- [ ] L'installation PWA fonctionne
- [ ] L'app fonctionne offline (service worker)
- [ ] Les notifications push fonctionnent (si activées)

### 8. Backend
- [ ] Les messages s'envoient correctement
- [ ] Les messages se reçoivent en temps réel (WebSocket)
- [ ] La transcription API fonctionne
- [ ] Les contacts se synchronisent
- [ ] Les réactions s'enregistrent

## 🐛 Debugging

### Voir les Logs Netlify
```bash
netlify logs
```

### Console du Navigateur
Ouvrir DevTools (F12) et vérifier:
- Onglet Console: erreurs JavaScript
- Onglet Network: requêtes API qui échouent
- Onglet Application > Service Workers: statut PWA

### Tester en Local
```bash
# Servir le build localement
cd build/web
python3 -m http.server 8000

# Ou avec flutter
flutter run -d chrome
```

## 🔧 Problèmes Courants

### 1. "Failed to load ad" (PropellerAds)
**Solution**: 
- Vérifier que les Zone IDs sont corrects
- Activer le test mode dans PropellerAds dashboard
- Vérifier la console pour les erreurs CORS

### 2. Messages vocaux ne s'enregistrent pas
**Solution**:
- Vérifier les permissions micro dans le navigateur
- Tester sur HTTPS (required pour getUserMedia)
- Vérifier la console pour erreurs permission_handler

### 3. Images ne se chargent pas
**Solution**:
- Vérifier les URLs des images (CORS)
- Vérifier flutter_cache_manager config
- Nettoyer le cache: `CacheService().clearAllCaches()`

### 4. WebSocket ne se connecte pas
**Solution**:
- Vérifier que le backend est accessible
- Tester wss://omnisms-backend.onrender.com/ws dans Postman
- Vérifier les tokens d'authentification
- Vérifier les logs côté backend

### 5. Build échoue sur Netlify
**Solution**:
- Vérifier que `netlify.toml` est présent
- Vérifier la version de Flutter (`FLUTTER_VERSION`)
- Consulter les logs de build Netlify
- Tester le build localement

## 📊 Monitoring

### Netlify Analytics
- Visites
- Bande passante
- Erreurs 4xx/5xx

### PropellerAds Dashboard
- Impressions
- Clicks
- Revenue (CPM, CPC)
- Fill rate

### Firebase Console
- Utilisateurs actifs
- Crashlytics (erreurs)
- Performance monitoring

## 🔒 Sécurité

### Variables d'Environnement
Ne jamais commit:
- API Keys Firebase
- Tokens d'authentification
- Secrets PropellerAds

Utiliser Netlify Environment Variables pour les secrets.

### HTTPS
- Toujours déployer en HTTPS
- Netlify fournit SSL gratuit
- Nécessaire pour PWA et microphone

## 📈 Optimisations Futures

- [ ] Ajouter le lazy loading d'images
- [ ] Implémenter la compression d'images avant upload
- [ ] Ajouter un CDN pour les assets statiques
- [ ] Optimiser le bundle size (tree-shaking)
- [ ] Ajouter des tests unitaires et d'intégration
- [ ] Configurer Lighthouse CI
- [ ] Ajouter le monitoring de performance (Sentry)

## 📚 Ressources

- [Flutter Web Docs](https://docs.flutter.dev/platform-integration/web)
- [Netlify Docs](https://docs.netlify.com/)
- [PropellerAds Docs](https://propellerads.com/blog/category/guides/)
- [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)

## 🎉 C'est Tout!

Votre application OmniSMS est maintenant déployée et prête à être utilisée! 🚀

Pour toute question ou problème, consultez les logs et la documentation ci-dessus.
