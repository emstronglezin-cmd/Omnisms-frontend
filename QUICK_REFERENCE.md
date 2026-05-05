# ⚡ Quick Reference - OmniSMS PWA

## 🚀 Commandes de Déploiement

### Build Local
```bash
flutter build web --release --web-renderer canvaskit
```

### Deploy Firebase
```bash
firebase deploy --only hosting
```

### Test Local
```bash
cd build/web
python3 -m http.server 8080
# Ouvrir http://localhost:8080
```

## 🔧 Configuration

### 1. Firebase Service Account (OBLIGATOIRE)
```bash
# Générer la clé
firebase init hosting:github

# Ajouter dans GitHub Settings > Secrets:
# Name: FIREBASE_SERVICE_ACCOUNT
# Value: [Contenu du JSON]
```

### 2. Google Analytics 4 (OPTIONNEL)
**Fichier:** `lib/services/analytics_service.dart`
```dart
static const String _measurementId = 'G-XXXXXXXXXX'; // Ligne 9
```

### 3. FCM VAPID Key (OPTIONNEL)
**Fichier:** `lib/services/web_notification_service.dart`
```dart
vapidKey: 'VOTRE-VAPID-KEY-ICI', // Ligne 39
```

## 📊 Vérifications

### GitHub Actions
```bash
# Voir les workflows
https://github.com/emstronglezin-cmd/Omnisms-frontend/actions

# Déclencher manuellement
Actions > Build & Deploy Web PWA > Run workflow
```

### Firebase Hosting
```bash
# Voir les déploiements
firebase hosting:channel:list

# Logs
firebase hosting:channel:open live
```

### Tests Lighthouse
```bash
npm install -g lighthouse
lighthouse https://omnisms-b98c5.web.app --view
```

## 🐛 Debugging

### Service Worker
```javascript
// DevTools > Console
navigator.serviceWorker.getRegistration()
  .then(reg => console.log(reg))

// Voir les notifications
Notification.permission
```

### Analytics
```javascript
// DevTools > Console
gtag('event', 'test', {test: true})

// Voir en temps réel
https://analytics.google.com → Realtime
```

### Cache Offline
```dart
// Dart DevTools ou print
final cache = await OfflineStorageService().getCacheSize();
print(cache);
```

## 📱 URLs de Production

- **Live:** https://omnisms-b98c5.web.app
- **Alt:** https://omnisms-b98c5.firebaseapp.com
- **Backend:** https://omnisms-backend.onrender.com
- **Abonnement:** https://www.pay.moneyfusion.net/abonnement-a-omnisms-_1762539771460/

## 🔗 Liens Rapides

- **Repo:** https://github.com/emstronglezin-cmd/Omnisms-frontend
- **Actions:** https://github.com/emstronglezin-cmd/Omnisms-frontend/actions
- **Firebase Console:** https://console.firebase.google.com/project/omnisms-b98c5
- **Analytics:** https://analytics.google.com
- **FCM Console:** https://console.firebase.google.com/project/omnisms-b98c5/notification

## 📚 Documentation

- `COMPLETE_PWA_GUIDE.md` - Guide complet (13KB)
- `GITHUB_SECRETS_SETUP.md` - Setup CI/CD
- `FINAL_SUMMARY.md` - Résumé final
- `PWA_DOCUMENTATION.md` - Doc PWA

## ⚙️ Workflow CI/CD

Le workflow **se déclenche automatiquement** sur:
- ✅ Push vers `main` → Build + Deploy
- ✅ Push vers `feature/*` → Build uniquement
- ✅ Pull Request vers `main` → Build + Tests
- ✅ Manuel via Actions tab

**Temps estimé:** 10-15 minutes par build

## 🎯 Checklist Post-Deploy

- [ ] App accessible sur https://omnisms-b98c5.web.app
- [ ] PWA installable (attendre 3s, cliquer "Installer")
- [ ] Mode offline fonctionne (DevTools > Network > Offline)
- [ ] Notifications activées (permission demandée)
- [ ] Service worker actif (DevTools > Application > Service Workers)
- [ ] Analytics track les événements (GA4 Realtime)
- [ ] Lighthouse score >90

## 💡 Tips

### Clear Cache
```javascript
// DevTools > Application > Storage > Clear site data
// Ou
caches.keys().then(keys => keys.forEach(key => caches.delete(key)))
```

### Force Update Service Worker
```javascript
// DevTools > Application > Service Workers
// Cliquer sur "Update" ou "Skip waiting"
```

### Test Notifications
```dart
// Dans l'app
await WebNotificationService().sendTestNotification();
```

### View Offline Data
```dart
final contacts = await OfflineStorageService().getContacts();
final pending = await OfflineStorageService().getPendingActions();
print('Contacts: ${contacts.length}, Pending: ${pending.length}');
```

## 🚨 En Cas de Problème

### Build échoue
```bash
flutter clean
flutter pub get
flutter build web --debug  # Plus rapide
```

### Deploy échoue
- Vérifier Firebase Service Account dans GitHub Secrets
- Vérifier les permissions du compte de service
- Voir les logs dans Actions

### Notifications ne marchent pas
- Vérifier VAPID Key
- Vérifier permissions navigateur
- Vérifier service worker enregistré

### Analytics ne track pas
- Vérifier Measurement ID
- Ouvrir DevTools > Console (voir les événements)
- Vérifier dans GA4 Realtime

## 📞 Support

**Issues:** https://github.com/emstronglezin-cmd/Omnisms-frontend/issues

**Documentation:**
- Flutter Web: https://docs.flutter.dev/platform-integration/web
- Firebase Hosting: https://firebase.google.com/docs/hosting
- PWA: https://web.dev/progressive-web-apps

---

**Version:** 2.2.0+4  
**Status:** ✅ Production Ready  
**Last Update:** 2026-04-18
