# OmniSMS — Context (Architecture & Règles)

> Dernière mise à jour : 2026-08-29  
> Version UI : v5.1 (Liquid Glass Edition)  
> Ce fichier doit être lu **en premier** par toute nouvelle session IA.

---

## 1. Architecture Générale

OmniSMS est une application de messagerie duale :
- **PWA** (Progressive Web App) — HTML/CSS/JS vanilla, déployée sur Vercel
- **Application Android Flutter** — Material 3, Provider pattern, Dart

Les deux partagent le même backend et les mêmes données.

```
┌─────────────────────────────────────────────────────────┐
│                    FRONTEND REPO                        │
│  /public/          → PWA (HTML/CSS/JS)                  │
│  /lib/             → Flutter App (Dart)                 │
│  /android/         → Android native config              │
│  vercel-build.sh   → build Flutter web → build/web      │
└─────────────────────────────────────────────────────────┘
                          ↕ API REST + Socket.IO
┌─────────────────────────────────────────────────────────┐
│                    BACKEND REPO                         │
│  Express.js 4.x    → https://omnisms-backend.onrender.com│
│  MongoDB           → Atlas cloud                        │
│  Render free tier  → cold start ~50s                    │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Repositories

| Repo | URL | Branch |
|------|-----|--------|
| Frontend | github.com/emstronglezin-cmd/Omnisms-frontend | main |
| Backend | (Render deployment) | main |

---

## 3. Frontend PWA (`/public/`)

### Stack
- HTML5 / CSS3 / Vanilla JavaScript (ES2020+)
- Socket.IO 4.7.5 (CDN)
- Service Worker pour offline PWA

### Fichiers principaux
| Fichier | Rôle | Lignes |
|---------|------|--------|
| `index.html` | Structure HTML, tous les IDs | ~512 |
| `style.css` | Système de design complet v5.1 | ~2425 |
| `app.js` | Logique complète PWA | ~2275 |
| `manifest.json` | Config PWA (nom, icônes, theme) | — |
| `sw.js` | Service Worker cache v4.3.0 | — |

### Design System v5.1 (Liquid Glass Edition)
```css
--bg-primary:   #08090f      /* fond principal */
--accent:       #00c8ff      /* cyan OmniSMS */
--accent-2:     #0057ff      /* deep blue */
--glass-bg:     rgba(14,17,24,0.72)   /* surface Liquid Glass */
--glass-blur:   blur(20px)            /* flou backdrop */
```

### IDs critiques (NE JAMAIS supprimer)
`screen-splash`, `screen-login`, `screen-register`, `screen-dashboard`, `screen-conversation`,
`login-email`, `login-password`, `login-btn`, `login-error`,
`register-name`, `register-phone`, `register-email`, `register-password`, `reg-username`, `register-btn`, `register-error`,
`user-avatar`, `tab-messages`, `tab-contacts`, `tab-groups`, `tab-settings`,
`nav-messages`, `nav-contacts`, `nav-groups`, `nav-settings`,
`conversations-list`, `contacts-list`, `groups-list`, `settings-content`,
`conv-screen-name`, `conv-screen-sub`, `conv-messages`, `conv-msg-input`,
`conv-appbar-avatar`, `conv-back-btn`, `conv-members-btn`, `mic-btn`, `recording-timer`,
`modal-add-contact`, `modal-create-group`, `modal-group-members`, `modal-edit-group`, `modal-payment`,
`modal-install`, `topbar-install-btn`, `toast`

### Bouton d'installation (Phase 6 + Phase 6b)
- ID : `topbar-install-btn` dans la topbar (classe `install-btn`, pill Liquid Glass)
- Handler : `openInstallModal()` → détection plateforme → `showInstallView(view)`
- Vues : `install-view-main`, `install-view-ios`, `install-view-android`
- Config APK : constante `ANDROID_APK_URL` dans app.js (vide = "coming soon")
- Détection plateforme : `_detectPlatform()` → `{ isIOS, isAndroid, isStandalone }`
  - iPhone/iPad → vue iOS directement
  - Android Chrome + prompt natif → `beforeinstallprompt` déclenché
  - Autres → vue principale (choix)
- `_pwaInstallPrompt` : capture `beforeinstallprompt`, déclenche l'install native Chrome
- `install-btn--ready` : classe CSS ajoutée quand le prompt natif est disponible (glow pulse)
- iOS icône : 🍎 dans la vue de choix principale

---

## 4. Frontend Flutter (`/lib/`)

### Stack
- Flutter 3.x / Dart 3.4+
- Provider pattern (6 providers)
- Material 3

### Providers
| Provider | Responsabilité |
|----------|---------------|
| `AuthProvider` | Login/Register/Logout, `currentUser` |
| `ThemeProvider` | Thème dark/light, **couleurs OmniSMS** |
| `MessagingProvider` | Conversations, messages |
| (autres) | Contacts, Groupes, Settings |

### Couleurs officielles (après Phase 3)
```dart
OmniColors.accent   = Color(0xFF00C8FF)  // cyan
OmniColors.accent2  = Color(0xFF0057FF)  // deep blue
OmniColors.bgPrimary = Color(0xFF08090F) // fond
```

### Widgets Liquid Glass (`/lib/widgets/common/liquid_glass.dart`)
- `LiquidGlassCard` — card avec BackdropFilter + reflet
- `LiquidGlassAppBar` — AppBar frosted glass
- `OmniGradientText` — texte gradient cyan→blue
- `OmniAvatarWidget` — avatar avec gradient OmniSMS
- `OmniGradientButton` — bouton gradient principal
- `OmniMessageBubble` — bulle message Liquid Glass

---

## 5. Backend (`https://omnisms-backend.onrender.com`)

### Stack
- Node.js + Express.js 4.x
- MongoDB Atlas
- Socket.IO 4.x
- Render free tier (cold start ~50s)

### Endpoints principaux
```
POST /api/auth/register
POST /api/auth/login
GET  /api/auth/me
GET  /api/messages/conversations
POST /api/messages/send
GET  /api/contacts
POST /api/contacts
GET  /api/groups
POST /api/groups
```

### Statut
- v4.2.0 — 13/13 tests passent
- ⛔ NE PAS MODIFIER le backend

---

## 6. Services Externes

| Service | Usage | Status |
|---------|-------|--------|
| Render | Hébergement backend | ✅ Actif |
| Vercel | Hébergement PWA | ✅ Actif |
| MongoDB Atlas | Base de données | ✅ Actif |
| Socket.IO CDN | WebSocket temps réel | ✅ Actif |
| Start.io | Publicités Android | ⚠️ Config requise |

---

## 7. Publicité

### Android — Start.io
- SDK : `startapp_sdk: ^1.0.1` (pub.dev)
- Fichier service : `/lib/services/ads_service.dart`
- Widget bannière : `BannerAdWidget()`
- **RÈGLE** : `_isPremium = true` → ads désactivées
- Méthode Premium check : via `PaymentService.getUserPremiumStatus()`
- **⚠️ CONFIGURATION** : Remplacer `YOUR_START_IO_APP_ID` dans :
  - `lib/services/ads_service.dart` (const `_kStartIoAppId`)
  - `android/app/src/main/AndroidManifest.xml` (meta-data)
- Obtenir l'App ID : https://portal.start.io/

### PWA — À définir (voir PROJECT_STATUS.md Phase 5)

---

## 8. Android

### Configuration actuelle
- `applicationId = "com.example.omni_smsnew"` ← dev ID, à changer en prod
- `targetSdk = 33`
- Signing : `omnisms-keystore.jks`, password `FASO2009`, alias `OmniSMS`
- Fichier keystore : `/home/user/frontend/omnisms-keystore.jks`

### Build APK
```bash
cd /home/user/frontend
bash build_apk.sh
# ou
flutter build apk --release --split-per-abi
```
⛔ **NE PAS lancer le build automatiquement — demander d'abord**

---

## 9. Vercel Deploy

### Config
```json
{
  "buildCommand": "bash ./vercel-build.sh",
  "outputDirectory": "build/web"
}
```

### Procédure
```bash
cd /home/user/frontend
# Via gsk ou vercel CLI
gsk hosted_deploy
```

---

## 10. Premium System

### PWA
```javascript
// Dans State.user
State.user.isSubscribed === true  // utilisateur premium
```

### Flutter
```dart
// Dans subscription_screen.dart
result['premium'] == true || result['isSubscribed'] == true
// Via PaymentService.getUserPremiumStatus()
```

### Règle absolue
- Utilisateur GRATUIT → publicités Start.io actives (Android)
- Utilisateur PREMIUM → publicités désactivées
- NE PAS toucher au système de paiement

---

## 11. Règles à ne jamais casser

1. ✅ **Tous les IDs HTML du PWA sont sacrés** — ne jamais renommer
2. ✅ **Les handlers JS sont sacrés** — ne jamais supprimer
3. ✅ **Backend inchangeable** — zéro modification sans permission explicite
4. ✅ **Paiement inchangeable** — PaymentService est hors scope
5. ✅ **Mode offline déjà codé** — ne pas refaire
6. ✅ **Couleurs OmniSMS** : `#00c8ff` (accent), `#0057ff` (accent-2), `#08090f` (bg)
7. ✅ **APK build** — demander permission avant de lancer
8. ✅ **Socket.IO rooms** — `user:{uid}`, conversations `[UID_A, UID_B].sort().join('-')`

---

## 12. Liquid Glass — Principes

Implémentés via :
```css
backdrop-filter: blur(20px);
background: rgba(14, 17, 24, 0.72);
border: 1px solid rgba(255,255,255,0.09);
box-shadow: inset 0 1px 0 rgba(255,255,255,0.07);
/* Reflet top */
background: linear-gradient(160deg, rgba(255,255,255,0.055) 0%, transparent 100%);
```

Appliqués sur : `.topbar`, `.bottom-nav`, `.conv-appbar`, `.conv-input-bar`, `.modal-sheet`, `.auth-card`, `#toast`, `.msg-them .msg-bubble`

Fallback `@supports not (backdrop-filter: blur(1px))` inclus pour anciens navigateurs.

---

## 13. Google Auth + Google Contacts (intégration Flutter)

> Contrat backend : `docs/GOOGLE_AUTH_FLUTTER.md` du repo **Omnisms-backend**.
> Le backend reste responsable de Google People API, de la normalisation, de la
> déduplication et de l'association numéro → utilisateur OmniSMS.

### Endpoints backend utilisés (aucun autre)

| Étape | Méthode & route | Auth |
|-------|-----------------|------|
| Démarrer la connexion Google | `GET  /api/auth/google` (ouvert dans le navigateur système) | — |
| Échanger le code contre la session | `POST /api/auth/google/exchange` `{ "code": "…" }` | — |
| Profil / session courante | `GET  /api/auth/me` | Bearer |
| Autoriser Google Contacts | `POST /api/auth/google/contacts/authorize` | Bearer |
| Importer les contacts Google | `POST /api/contacts/google/import` | Bearer |

Toutes les routes sont construites depuis `ApiConfig.baseUrl`
(`https://omnisms-backend.onrender.com`) — aucune URL en dur ailleurs.

### Deep links (mécanisme de retour imposé par le backend)

```
omnisms://auth/google/callback?code=<code à usage unique>   → connexion
omnisms://auth/google/callback?error=GOOGLE_OAUTH_DENIED    → refus
omnisms://auth/google/contacts/callback?authorized=1        → contacts autorisés
omnisms://auth/google/contacts/callback?error=…             → refus contacts
```

- Aucun JWT OmniSMS ni token Google ne circule dans l'URL : le backend ne
  renvoie qu'un code d'échange (valable 2 min, usage unique).
- Configuration native : `android/app/src/main/AndroidManifest.xml`
  (intent-filter `omnisms://auth` + `flutter_deeplinking_enabled=false`) et
  `ios/Runner/Info.plist` (`CFBundleURLTypes` + `FlutterDeepLinkingEnabled=false`).
- Plugin : `app_links` (Android/iOS/desktop/web).
- **Web/PWA** : les schémas personnalisés ne fonctionnent pas dans un
  navigateur. Pour le web, `GOOGLE_FLUTTER_REDIRECT_URI` et
  `GOOGLE_CONTACTS_FLUTTER_REDIRECT_URI` doivent pointer vers l'URL HTTPS
  déployée côté backend (Render). Le code relit alors `Uri.base`.

### Fichiers concernés

| Fichier | Rôle |
|---------|------|
| `lib/services/google_oauth_flow.dart` | Écoute des deep links, ouverture navigateur, parsing des callbacks, messages utilisateur |
| `lib/services/auth_service.dart` | `loginWithGoogle()` + échange du code (même stockage que `login()`) |
| `lib/providers/auth_provider.dart` | `loginWithGoogle()`, session persistante, session expirée (401) |
| `lib/screens/auth/login_screen.dart` | Bouton « Continuer avec Google » |
| `lib/services/contacts_service_v2.dart` | `requestGoogleContactsAuthorization()`, `importGoogleContacts()` |
| `lib/providers/contacts_provider_v2.dart` | `importFromGoogle()` + états `GoogleImportState` |
| `lib/screens/contacts/contacts_screen_v2.dart` | Action « Importer depuis Google » |

### Règles

1. **Un seul système de session** : le JWT OmniSMS (clé `auth_token`) est le
   même pour login email/mot de passe et Google. Jamais de second token.
2. **Aucun token Google côté Flutter** — ni stocké, ni transmis.
3. **Après import Google → `loadContacts()`** : la liste est rechargée depuis
   le backend, jamais fusionnée localement (déduplication côté serveur).
4. Les contacts Google arrivent dans la même liste que les contacts manuels et
   VCF (`source: "google"`, statut OmniSMS via `isOnOmniSms`).
5. Les erreurs affichées sont des messages utilisateur : jamais de stack
   trace, de token ou de détail OAuth.

### Variables backend requises (Render)

`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`,
`GOOGLE_FLUTTER_REDIRECT_URI`, `GOOGLE_CONTACTS_FLUTTER_REDIRECT_URI`,
`GOOGLE_TOKEN_ENCRYPTION_KEY` — rien de tout cela ne vit dans le frontend.
