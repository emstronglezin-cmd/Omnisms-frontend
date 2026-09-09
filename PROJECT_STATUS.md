# OmniSMS — Project Status

> Dernière mise à jour : 2026-08-29  
> Session : Liquid Glass + Mobile + Ads + Distribution

---

## ✅ Terminé

### Backend (Session précédente)
- [x] P0–P7 corrections backend stabilisation
- [x] Backend v4.2.0 — 13/13 tests passent
- [x] Offline SMS routing fixé
- [x] Payment webhook userId fallback fixé

### Visual Redesign v5.0 (Session précédente)
- [x] `style.css` — réécriture complète (801 → 1980 lignes), design system premium
- [x] `index.html` — structure premium, tous les 36+ IDs préservés
- [x] `app.js` — templates visuels mis à jour, zéro changement logique
- [x] Commit `22ca715` — "feat(ui): premium visual redesign v5.0"

### Liquid Glass + Mobile + Distribution (Session courante)
- [x] **Phase 0** — Audit complet du projet
  - Confirmé : Start.io absent → à installer
  - Confirmé : CONTEXT.md/PROJECT_STATUS.md absents → créés
  - Confirmé : Flutter theme Indigo → corrigé OmniSMS cyan
  - Confirmé : PWA safe areas partiellement OK → amélioré

- [x] **Phase 1** — Liquid Glass PWA (`style.css` v5.1)
  - Topbar : `backdrop-filter: blur(20px)` + reflet inset
  - Bottom nav : Liquid Glass + reflet horizontal
  - Conv appbar : Liquid Glass complet
  - Input bar : `backdrop-filter: blur(12px)` + safe-bottom
  - Modal overlay : `blur(8px)` amélioré
  - Modal sheet : Liquid Glass fort + shadow côté haut
  - Auth card : Liquid Glass + reflet accent
  - Msg received : Liquid Glass subtil
  - Toast : Liquid Glass
  - Fallback `@supports not (backdrop-filter)` inclus
  - `prefers-reduced-motion` respecté

- [x] **Phase 2** — iPhone/PWA Safe Areas & Mobile
  - `--safe-left`/`--safe-right` ajoutés
  - `#screen-dashboard`/`#screen-conversation` : padding safe areas
  - `#screen-splash` : padding safe top/bottom
  - Auth screens : safe area corrigée
  - Tous les touch targets ≥ 44×44px (iOS HIG)
  - `height: 100dvh` pour keyboard resize
  - `.conv-input-bar` : `padding-bottom: calc(10px + var(--safe-bottom))`
  - Tap active state micro-animations

- [x] **Phase 3** — Flutter Android
  - `theme_provider.dart` : Indigo remplacé par OmniSMS cyan `#00c8ff`
  - `OmniColors` class créée avec tous les tokens
  - Dark theme complet : AppBar, NavigationBar, Cards, Inputs, Buttons, Text
  - `SystemUiOverlayStyle` configuré dark-first
  - Widget library `liquid_glass.dart` créée :
    - `LiquidGlassCard` + `LiquidGlassAppBar`
    - `OmniGradientText` + `OmniAvatarWidget`
    - `OmniGradientButton` + `OmniMessageBubble`

- [x] **Phase 4** — Start.io Android
  - `startapp_sdk: ^1.0.1` ajouté dans `pubspec.yaml`
  - `lib/services/ads_service.dart` créé :
    - `AdsService.initialize()` → initialisation SDK
    - `AdsService.loadBanner()` → bannière
    - `AdsService.showInterstitial()` → plein écran
    - `AdsService.setPremiumStatus()` → gate premium
    - `BannerAdWidget()` → widget plug-and-play
  - `AndroidManifest.xml` : meta-data `com.startapp.sdk.APPLICATION_ID` ajouté
  - ⚠️ **CONFIGURATION REQUISE** : Remplacer `YOUR_START_IO_APP_ID`

- [x] **Phase 6** — Bouton Installation/Distribution
  - `topbar-install-btn` dans la topbar (pill Liquid Glass)
  - Modal `modal-install` avec 3 vues
  - Vue principale : choix iPhone (🍎) / Android (🤖)
  - Vue iOS : 5 étapes illustrées + warning Safari obligatoire
  - Vue Android : APK download si `ANDROID_APK_URL` défini, sinon "coming soon"
  - Fonctions JS : `openInstallModal()`, `showInstallView()`, `_renderAndroidInstallContent()`

- [x] **Phase 6b** — Améliorations bouton install (2026-09-09)
  - Détection plateforme : `_detectPlatform()` → iPhone ouvre vue iOS directement
  - `beforeinstallprompt` capturé → install PWA native Chrome/Android sans APK
  - `appinstalled` écouté → toast de confirmation + nettoyage prompt
  - `install-btn--ready` : animation glow pulse quand install native disponible
  - `_renderAndroidInstallContent()` : 3 cas — PWA prompt / APK URL / "coming soon"
  - iOS icon 🍎 ajouté dans la vue de choix principale
  - `@media (prefers-reduced-motion)` : animation désactivée
  - Tests : 11/11 PASS (A1-A4 Desktop, B1-B2 iOS, C1-C2 Android, D1 PWA prompt, E1 fermeture, F1 APK URL)

- [x] **Phase 7** — Fichiers de contexte
  - `CONTEXT.md` créé (architecture, règles, config)
  - `PROJECT_STATUS.md` créé (ce fichier)

---

## 🔄 En cours

- [ ] **Phase 8** — Tests réels (en cours de documentation)
- [ ] **Phase 9** — Commit + Push + Vercel deploy

---

## ⏳ À faire / Prochaines sessions

### Config requise avant production
- [ ] Remplacer `YOUR_START_IO_APP_ID` dans `ads_service.dart` et `AndroidManifest.xml`
  → Obtenir sur https://portal.start.io/
- [ ] Intégrer `BannerAdWidget()` dans les écrans Flutter appropriés
  → Suggestions : bas de `MessagesListPage`, bas de `ContactsPage`
  → ⛔ JAMAIS dans `ConversationScreen` pendant la saisie
- [ ] Appeler `AdsService().setPremiumStatus(isPremium)` au login
- [ ] Appeler `AdsService().initialize()` dans main.dart

### PWA Advertising (Phase 5 — après validation)
- [ ] Choisir un fournisseur publicitaire PWA (voir tableau Phase 5 ci-dessous)
- [ ] Intégrer uniquement après validation explicite

### Distribution
- [ ] Générer l'APK Android (demander permission)
- [ ] Héberger l'APK
- [ ] Mettre à jour `ANDROID_APK_URL` dans `app.js`

### Optionnel (améliorations futures)
- [ ] Changer `applicationId = "com.example.omni_smsnew"` en ID production
- [ ] Intégrer `LiquidGlassAppBar` dans les écrans Flutter
- [ ] Intégrer `OmniMessageBubble` dans `ConversationScreen`
- [ ] Tester Flutter build avec le nouveau `startapp_sdk`

---

## 📋 Phase 5 — Comparatif Publicité PWA

> Recherche effectuée 2026-08-29. À valider avant intégration.

| Solution | Compatible PWA | Accessible Afrique | Inscription | Retrait (min) | Avantages | Limites |
|----------|---------------|-------------------|-------------|---------------|-----------|---------|
| **Google AdSense** | ✅ Oui | ⚠️ Partiel | Site 3+ mois, contenu original, +18 ans, Google Account | $100 | Marque connue, CPM élevé pays T1 | Approbation stricte, paiement virement difficile en Afrique |
| **Adsterra** | ✅ Oui | ✅ Excellent | Inscription simple, 0 minimum trafic | $5 | Très accessible en Afrique, formats variés (Social Bar, Popunder), approbation facile | CPM bas pour trafic T3 |
| **Monetag** (ex-PropellerAds) | ✅ Oui | ✅ Bon | 0 minimum trafic, inscription simple | $5 (PayPal/Skrill) / $20-30 (Payoneer) | Push notifications, popunder, SmartLink, paiement Payoneer | CPM Africa bas |
| **PropellerAds** | ✅ Oui | ✅ Bon | 0 minimum trafic | $5 | Formats poussées, interstitiels PWA | Maintenant Monetag, ads intrusives |
| **Media.net** | ✅ Oui | ❌ Limité | Site anglophone, trafic US/UK/CA préféré | $100 | Bon CPM trafic T1 | Difficile pour trafic africain |
| **InMobi** | ✅ Oui | ✅ Présent | Inscription entreprise requise | Variable | Spécialiste mobile, présent en Afrique | Processus d'inscription complexe |

### 🏆 Recommandations pour OmniSMS

**Option 1 — Démarrage rapide :** **Adsterra**
- Zéro minimum trafic
- Inscription en 24h
- Paiement Payoneer/PayPal/Tether
- Très populaire chez les publishers africains
- Social Bar : format discret, compatible PWA

**Option 2 — Croissance :** **Monetag**
- Si > 10K visiteurs/mois
- Push notifications = revenus passifs
- Paiement Payoneer disponible

**Option 3 — Long terme :** **Google AdSense**
- Uniquement si site avec contenu original (pas juste app)
- Revenu beaucoup plus élevé par clic
- Nécessite compte Google vérifié + site approuvé

### ⚠️ Risques identifiés
- Aucune plateforme ne garantit l'acceptation sans vérification manuelle
- Adsterra et Monetag acceptent historiquement les développeurs africains sans contraintes documentaires lourdes
- Le retrait via Payoneer depuis l'Afrique subsaharienne est possible et documenté

---

## 🐛 Problèmes connus

| Problème | Gravité | Reproduction | État |
|----------|---------|--------------|------|
| Start.io App ID non configuré | 🟡 Medium | Ads ne s'affichent pas | En attente config |
| ANDROID_APK_URL vide | 🟢 Low | Affiche "coming soon" (comportement attendu) | Normal jusqu'au build APK |
| Flutter build non testé avec startapp_sdk | 🟡 Medium | N/A | Nécessite flutter pub get + build test |
| applicationId dev = com.example.omni_smsnew | 🟢 Low | Store listing | À renommer pour production |

---

## 📁 Fichiers modifiés (session 2026-09-09)

| Fichier | Changement |
|---------|-----------|
| `public/app.js` | Phase 6b : `_detectPlatform()`, `_pwaInstallPrompt` capture `beforeinstallprompt`, `openInstallModal()` plateforme-aware, `_renderAndroidInstallContent()` 3 cas |
| `public/index.html` | Phase 6b : iOS icon 🍎 ajouté dans `install-choice-icon` |
| `public/style.css` | Phase 6b : `.install-btn--ready` + `@keyframes installPulse` + `prefers-reduced-motion` |

## 📁 Fichiers modifiés (session 2026-08-29)

| Fichier | Changement |
|---------|-----------|
| `public/style.css` | v5.0→v5.1 : Liquid Glass (2425 lignes) |
| `public/index.html` | Bouton install + modal install (512 lignes) |
| `public/app.js` | Functions install : `openInstallModal`, `showInstallView`, `_renderAndroidInstallContent` (2275 lignes) |
| `lib/providers/theme_provider.dart` | Thème OmniSMS complet (Indigo → cyan), `OmniColors` class |
| `lib/widgets/common/liquid_glass.dart` | NOUVEAU — widget library Liquid Glass |
| `lib/services/ads_service.dart` | NOUVEAU — Start.io integration + `BannerAdWidget` |
| `pubspec.yaml` | `startapp_sdk: ^1.0.1` ajouté |
| `android/app/src/main/AndroidManifest.xml` | Start.io App ID meta-data ajouté |
| `CONTEXT.md` | NOUVEAU — fichier de contexte complet |
| `PROJECT_STATUS.md` | NOUVEAU — ce fichier |

---

## 🔧 Dernière session — Actions

1. Audit complet du projet ✅
2. Phase 1 — Liquid Glass PWA ✅
3. Phase 2 — Safe areas + Mobile ✅
4. Phase 3 — Flutter theme OmniSMS + widget library ✅
5. Phase 4 — Start.io integration ✅
6. Phase 5 — Recherche pub PWA (tableau) ✅
7. Phase 6 — Bouton install distribution ✅
8. Phase 7 — Fichiers contexte ✅
9. Tests syntaxe JS : ✅ PASS
10. Git commit + push + Vercel deploy : 🔄 EN COURS

## ➡️ Prochaine étape immédiate

```bash
# 1. Vérifier les modifications
cd /home/user/frontend && git status

# 2. Commit
git add -A
git commit -m "feat(ui+mobile+ads): v5.1 Liquid Glass, Start.io, install button, OmniSMS theme"

# 3. Push
git push origin main

# 4. Vercel deploy
# via gsk hosted_deploy ou vercel CLI
```

Puis demander : **"Veux-tu que je lance maintenant le build APK Android ?"**
