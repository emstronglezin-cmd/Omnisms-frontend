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

### Bouton d'installation (Phase 6)
- ID : `topbar-install-btn` dans la topbar
- Handler : `openInstallModal()` → `showInstallView(view)`
- Vues : `install-view-main`, `install-view-ios`, `install-view-android`
- Config APK : constante `ANDROID_APK_URL` dans app.js (vide = "coming soon")

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
