# 🚀 OmniSMS - Guide Complet d'Implémentation PWA

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Fonctionnalités Implémentées](#fonctionnalités-implémentées)
4. [GitHub Actions CI/CD](#github-actions-cicd)
5. [Notifications Push Web (FCM)](#notifications-push-web-fcm)
6. [Mode Offline Avancé](#mode-offline-avancé)
7. [Google Analytics 4](#google-analytics-4)
8. [Optimisations Performance](#optimisations-performance)
9. [Tests Multi-Navigateurs](#tests-multi-navigateurs)
10. [Déploiement](#déploiement)

---

## 🎯 Vue d'ensemble

OmniSMS est maintenant une **Progressive Web App (PWA) complète** avec:
- ✅ Build automatique via GitHub Actions
- ✅ Notifications push web (FCM)
- ✅ Mode offline avancé (IndexedDB via SharedPreferences)
- ✅ Google Analytics 4
- ✅ Lazy loading et optimisations
- ✅ Tests multi-navigateurs
- ✅ Déploiement automatique sur Firebase

---

## 🏗️ Architecture

### Structure des Fichiers

```
lib/
├── layouts/
│   ├── responsive_layout.dart          # Layout responsive
│   ├── web_sidebar.dart                # Sidebar navigation
│   └── web_main_layout.dart            # Layout principal web
├── services/
│   ├── web_notification_service.dart   # Notifications FCM
│   ├── offline_storage_service.dart    # Cache offline
│   ├── analytics_service.dart          # Google Analytics 4
│   └── [autres services existants]
├── widgets/
│   └── lazy_load_widget.dart           # Widgets lazy loading
├── screens/
│   └── [écrans existants adaptés]
└── main.dart

.github/
└── workflows/
    └── deploy-web.yml                  # CI/CD GitHub Actions

web/
├── index.html                          # HTML optimisé PWA
├── manifest.json                       # Manifest PWA
└── firebase-messaging-sw.js            # Service worker FCM
```

---

## ✨ Fonctionnalités Implémentées

### 1. Notifications Push Web (FCM) ✅

**Fichier:** `lib/services/web_notification_service.dart`

**Fonctionnalités:**
- Demande de permission automatique
- Token FCM pour web (VAPID)
- Écoute des messages en foreground
- Gestion des clics sur notifications
- Topics pour notifications groupées
- Notifications in-app personnalisées

**Utilisation:**

```dart
// Dans main.dart
import 'services/web_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... Firebase init ...
  
  // Initialiser les notifications
  final notifService = WebNotificationService();
  await notifService.initialize();
  
  // Écouter les notifications
  notifService.onNotification.listen((message) {
    print('Notification reçue: ${message.notification?.title}');
  });
  
  runApp(MyApp());
}

// Envoyer une notification de test
await WebNotificationService().sendTestNotification();

// S'abonner à un topic
await WebNotificationService().subscribeToTopic('all_users');
```

**Configuration Backend:**

Votre backend doit envoyer des notifications au format FCM:

```bash
POST https://fcm.googleapis.com/v1/projects/omnisms-b98c5/messages:send
Authorization: Bearer YOUR_SERVER_KEY

{
  "message": {
    "token": "FCM_TOKEN_FROM_CLIENT",
    "notification": {
      "title": "Nouveau message",
      "body": "Vous avez reçu un message"
    },
    "data": {
      "type": "message",
      "conversationId": "123",
      "url": "/messages/123"
    },
    "webpush": {
      "fcm_options": {
        "link": "https://omnisms-b98c5.web.app/messages/123"
      }
    }
  }
}
```

**Service Worker:** `web/firebase-messaging-sw.js` (déjà créé)

---

### 2. Mode Offline Avancé ✅

**Fichier:** `lib/services/offline_storage_service.dart`

**Fonctionnalités:**
- Cache des contacts, messages, groupes
- Actions en attente (queue)
- Synchronisation automatique au retour en ligne
- Validation de cache (24h)
- Gestion de la taille du cache

**Utilisation:**

```dart
import 'services/offline_storage_service.dart';

final offlineStorage = OfflineStorageService();

// Sauvegarder des contacts
await offlineStorage.saveContacts(contacts);

// Récupérer des contacts (cache)
final cachedContacts = await offlineStorage.getContacts();

// Ajouter une action en attente
await offlineStorage.addPendingAction({
  'type': 'send_message',
  'data': {
    'to': '+1234567890',
    'content': 'Hello',
  },
});

// Synchroniser les actions en attente
await offlineStorage.syncPendingActions((action) async {
  if (action['type'] == 'send_message') {
    await messagingService.sendMessage(action['data']);
  }
});

// Vider le cache
await offlineStorage.clearCache();

// Obtenir la taille du cache
final sizes = await offlineStorage.getCacheSize();
print('Cache contacts: ${sizes['contacts']} bytes');
```

**Intégration avec les Providers:**

```dart
// Dans ContactsProvider
class ContactsProvider with ChangeNotifier {
  final _offlineStorage = OfflineStorageService();
  
  Future<void> loadContacts() async {
    // Essayer le cache d'abord
    final cached = await _offlineStorage.getContacts();
    if (cached.isNotEmpty) {
      _contacts = cached;
      notifyListeners();
    }
    
    // Puis charger depuis le serveur
    try {
      final fresh = await _contactsService.getContacts();
      _contacts = fresh;
      await _offlineStorage.saveContacts(fresh);
      notifyListeners();
    } catch (e) {
      // Si erreur et pas de cache, afficher erreur
      if (cached.isEmpty) rethrow;
    }
  }
}
```

---

### 3. Google Analytics 4 ✅

**Fichier:** `lib/services/analytics_service.dart`

**Fonctionnalités:**
- Tracking des pages
- Événements personnalisés
- Propriétés utilisateur
- E-commerce tracking
- Recherche et partage

**Configuration:**

1. Créer une propriété GA4:
   - Aller sur https://analytics.google.com
   - Créer une propriété GA4
   - Ajouter un flux de données Web
   - Copier votre ID de mesure (G-XXXXXXXXXX)

2. Mettre à jour `analytics_service.dart`:
   ```dart
   static const String _measurementId = 'G-VOTRE-ID-ICI';
   ```

**Utilisation:**

```dart
import 'services/analytics_service.dart';

final analytics = AnalyticsService();

// Initialiser
await analytics.initialize();

// Logger une page
analytics.logPageView('/dashboard');

// Logger un événement
analytics.logEvent('button_clicked', parameters: {
  'button_name': 'send_message',
  'screen': 'conversation',
});

// Logger une connexion
analytics.logLogin('email');

// Logger un achat
analytics.logPurchase(
  transactionId: 'TXN123',
  value: 2000.0,
  currency: 'XOF',
  itemName: 'Abonnement Premium',
);

// Définir l'utilisateur
analytics.setUserId('user123');
analytics.setUserProperties({
  'plan': 'premium',
  'country': 'BJ',
});
```

**Avec Mixin:**

```dart
class DashboardScreen extends StatelessWidget with AnalyticsMixin {
  @override
  Widget build(BuildContext context) {
    // Tracker automatiquement
    trackPageView('/dashboard');
    
    return Scaffold(
      // ...
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          trackEvent('fab_clicked');
          // ...
        },
      ),
    );
  }
}
```

---

### 4. Optimisations Performance ✅

**Fichier:** `lib/widgets/lazy_load_widget.dart`

#### A. Lazy Loading de Widgets

```dart
LazyLoadWidget(
  builder: () async {
    // Charger des données lourdes
    await Future.delayed(Duration(seconds: 2));
    return ExpensiveWidget();
  },
  placeholder: CircularProgressIndicator(),
  errorWidget: Text('Erreur de chargement'),
)
```

#### B. Lazy Loading de Listes (Pagination)

```dart
LazyLoadList<Contact>(
  fetchData: (page, limit) async {
    return await contactsService.getContacts(
      offset: page * limit,
      limit: limit,
    );
  },
  itemBuilder: (context, contact, index) {
    return ContactTile(contact: contact);
  },
  pageSize: 20,
  emptyWidget: Text('Aucun contact'),
)
```

#### C. Lazy Loading d'Images

```dart
LazyImage(
  imageUrl: 'https://example.com/avatar.jpg',
  width: 100,
  height: 100,
  fit: BoxFit.cover,
  placeholder: CircularProgressIndicator(),
  errorWidget: Icon(Icons.broken_image),
)
```

---

## 🤖 GitHub Actions CI/CD

**Fichier:** `.github/workflows/deploy-web.yml`

### Workflow Complet

Le workflow automatise:
1. ✅ Build Flutter Web
2. ✅ Analyse du code
3. ✅ Tests unitaires
4. ✅ Déploiement Firebase (branch main uniquement)
5. ✅ Tests multi-navigateurs (Chrome, Firefox)
6. ✅ Audit Lighthouse (performance)

### Configuration

#### 1. Secrets GitHub à ajouter

Aller dans **Settings > Secrets and variables > Actions** et ajouter:

- `FIREBASE_SERVICE_ACCOUNT`:
  ```bash
  # Générer la clé de service Firebase
  firebase login:ci
  # OU
  firebase init hosting:github
  ```
  
  Le JSON de la clé de service ressemble à:
  ```json
  {
    "type": "service_account",
    "project_id": "omnisms-b98c5",
    "private_key_id": "...",
    "private_key": "...",
    "client_email": "...",
    ...
  }
  ```

#### 2. Déclencher le Workflow

**Automatique:**
- Push sur `main` → Build + Deploy
- Push sur `feature/*` → Build uniquement
- Pull Request vers `main` → Build + Tests

**Manuel:**
- Aller dans **Actions** > **Build & Deploy Web PWA**
- Cliquer sur **Run workflow**

### Suivi du Build

1. Aller dans l'onglet **Actions** du repo
2. Cliquer sur le workflow en cours
3. Voir les logs en temps réel
4. Télécharger les artifacts (build web)

---

## 🧪 Tests Multi-Navigateurs

Le workflow teste automatiquement sur:
- ✅ Chrome
- ✅ Firefox

### Tests Manuels

#### Chrome/Edge
```bash
flutter run -d chrome
```

#### Firefox (via Playwright)
```bash
npm install -g playwright
playwright install firefox
cd build/web
python3 -m http.server 8080

# Dans un autre terminal
playwright test --browser=firefox
```

#### Safari (macOS uniquement)
```bash
flutter run -d safari
```

---

## 📊 Métriques et Monitoring

### Lighthouse Audit

Le workflow exécute automatiquement un audit Lighthouse. Résultats dans:
- **Actions** > **Workflow run** > **Artifacts** > **lighthouse-results**

**Objectifs:**
- Performance: >90
- Accessibility: >95
- Best Practices: >95
- SEO: >90
- PWA: 100

### Firebase Analytics

Tableau de bord: https://console.firebase.google.com/project/omnisms-b98c5/analytics

**Événements à surveiller:**
- `page_view` - Pages les plus visitées
- `message_sent` - Activité messaging
- `group_created` - Création de groupes
- `purchase` - Abonnements

### Crashlytics

Erreurs en prod: https://console.firebase.google.com/project/omnisms-b98c5/crashlytics

---

## 🚀 Déploiement

### Automatique (Recommandé)

Push vers `main` déclenche automatiquement:
1. Build web
2. Tests
3. Déploiement Firebase

### Manuel

```bash
# Build
flutter build web --release \
  --web-renderer canvaskit \
  --base-href "/" \
  --pwa-strategy offline-first

# Deploy
firebase deploy --only hosting

# URLs live:
# https://omnisms-b98c5.web.app
# https://omnisms-b98c5.firebaseapp.com
```

---

## ✅ Checklist de Mise en Production

### Pré-déploiement

- [ ] Remplacer les clés API de test
  - [ ] GA4 Measurement ID dans `analytics_service.dart`
  - [ ] FCM VAPID Key dans `web_notification_service.dart`
- [ ] Configurer Firebase Service Account dans GitHub Secrets
- [ ] Tester sur tous les navigateurs (Chrome, Firefox, Safari, Edge)
- [ ] Vérifier les performances (Lighthouse score >90)
- [ ] Tester le mode offline
- [ ] Tester les notifications push

### Post-déploiement

- [ ] Vérifier l'installation PWA
- [ ] Tester le service worker
- [ ] Vérifier Google Analytics (données en temps réel)
- [ ] Tester les notifications en production
- [ ] Monitorer Crashlytics pour les erreurs
- [ ] Vérifier la synchronisation offline

---

## 📝 Commandes Utiles

```bash
# Build debug (plus rapide)
flutter build web --debug

# Build avec rapport de taille
flutter build web --analyze-size

# Tester localement
cd build/web && python3 -m http.server 8080

# Voir les logs Firebase
firebase hosting:channel:list

# Déployer sur un channel de test
firebase hosting:channel:deploy test-v1

# Promouvoir un channel vers prod
firebase hosting:clone test-v1:live

# Nettoyer
flutter clean && flutter pub get
```

---

## 🐛 Troubleshooting

### Build échoue avec "Out of Memory"
- Augmenter la RAM disponible (4GB minimum)
- Utiliser `flutter build web --debug`

### Notifications ne fonctionnent pas
- Vérifier VAPID Key dans `web_notification_service.dart`
- Tester les permissions: `Notification.requestPermission()`
- Vérifier service worker: DevTools > Application > Service Workers

### Cache offline ne fonctionne pas
- Vérifier que SharedPreferences est bien configuré
- Tester: `final prefs = await SharedPreferences.getInstance()`

### Analytics ne track pas
- Vérifier Measurement ID
- Ouvrir DevTools > Console pour voir les événements
- Aller dans GA4 > Reports > Realtime

---

## 📞 Support et Ressources

- **Backend API**: https://omnismss-backend.onrender.com
- **Firebase Console**: https://console.firebase.google.com/project/omnisms-b98c5
- **GitHub Repo**: https://github.com/emstronglezin-cmd/Omnisms-frontend
- **Documentation Flutter Web**: https://docs.flutter.dev/platform-integration/web

---

**Version:** 2.2.0-web.2  
**Date:** 2026-04-18  
**Status:** ✅ Production Ready
