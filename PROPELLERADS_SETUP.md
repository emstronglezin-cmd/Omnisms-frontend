# 📺 Configuration PropellerAds - Guide Complet

## ✅ Statut Actuel

- ✅ **Zone ID configuré:** `11034847`
- ✅ **Fichier de vérification:** `web/sw.js` (placé à la racine du site)
- ✅ **Widget intégré:** `PropellerAdsBanner` prêt à l'emploi
- ✅ **Configuration:** `lib/config/ads_config.dart`

---

## 🔍 Vérification du Site (PropellerAds)

### Étape 1: Fichier de Vérification
Le fichier `sw.js` a été placé dans le dossier `web/`. Lors du build Flutter, il sera copié à la racine du site déployé.

**URL de vérification:** 
```
https://omnisms.netlify.app/sw.js
```

### Étape 2: Vérification PropellerAds
1. Allez sur votre dashboard PropellerAds
2. Trouvez votre site web/app
3. Cliquez sur "Verify" ou "Vérifier"
4. PropellerAds va chercher le fichier `sw.js` à la racine
5. ✅ Votre site sera vérifié automatiquement

---

## ⚙️ Configuration des Zone IDs

### Zone ID Actuel
Votre Zone ID principal: **11034847**

Ce Zone ID est actuellement utilisé pour tous les formats:
- Banner
- Interstitial
- Push Notifications
- Onclick/Popunder

### Configuration dans le Code

**Fichier:** `lib/config/ads_config.dart`

```dart
class AdsConfig {
  static const String bannerZoneId = '11034847';
  static const String interstitialZoneId = '11034847';
  static const String pushNotificationZoneId = '11034847';
  static const String onclickZoneId = '11034847';
  
  // Activer/désactiver les ads
  static bool get adsEnabled => true;
  
  // Placement des ads
  static const bool showAdsOnDashboard = true;
  static const bool showAdsOnContacts = true;
  static const bool showAdsOnGroups = true;
  static const bool showAdsOnConversation = false; // UX prioritaire
}
```

---

## 🎯 Créer des Zones Spécifiques (Optionnel)

Si vous voulez des zones différentes pour chaque format:

### 1. Dans PropellerAds Dashboard
- Créer une nouvelle zone pour "Banner"
- Créer une nouvelle zone pour "Interstitial"
- Créer une nouvelle zone pour "Push"
- Créer une nouvelle zone pour "Onclick"

### 2. Copier les Zone IDs

Exemple:
```
Banner Zone ID: 11034847
Interstitial Zone ID: 11034848
Push Zone ID: 11034849
Onclick Zone ID: 11034850
```

### 3. Mettre à jour le code

```dart
static const String bannerZoneId = '11034847';
static const String interstitialZoneId = '11034848';
static const String pushNotificationZoneId = '11034849';
static const String onclickZoneId = '11034850';
```

---

## 📱 Utilisation des Widgets

### Banner Ad (Bannière)

**Dashboard, Contacts, Groups:**
```dart
import 'package:omnisms/widgets/ads/propeller_ads_banner.dart';

// Dans votre widget
PropellerBannerAd(
  height: 90, // Hauteur en pixels
)
```

**Placement recommandé:**
- En bas du Dashboard
- En bas de la liste des contacts
- En bas de la liste des groupes

### Interstitial Ad (Plein écran)

À implémenter selon vos besoins (transitions entre écrans, etc.)

---

## 🧪 Test des Publicités

### Mode Test PropellerAds

1. **Activer le mode test** dans PropellerAds dashboard
2. **Déployer l'app** sur Netlify
3. **Visiter** https://omnisms.netlify.app
4. **Vérifier** que les ads s'affichent
5. **Cliquer** pour tester l'interaction

### Vérifications
- [ ] Les bannières s'affichent correctement
- [ ] Pas de console errors liées aux ads
- [ ] Les clicks fonctionnent
- [ ] Le layout n'est pas cassé
- [ ] Les ads ne bloquent pas l'UX

---

## 📊 Monitoring

### PropellerAds Dashboard

Métriques à surveiller:
- **Impressions**: Nombre d'affichages
- **Clicks**: Nombre de clicks
- **CTR**: Click-Through Rate (%)
- **Revenue**: Revenus générés (CPM, CPC)
- **Fill Rate**: Taux de remplissage des ads

### Objectifs
- CTR > 1%
- Fill Rate > 90%
- Revenue > $10/jour

---

## 🐛 Troubleshooting

### Les ads ne s'affichent pas

**1. Vérifier que le site est validé**
```bash
curl https://omnisms.netlify.app/sw.js
```
Devrait retourner le contenu du fichier.

**2. Vérifier la console browser**
Ouvrir DevTools (F12) → Console
Chercher erreurs liées à PropellerAds

**3. Vérifier que adsEnabled = true**
```dart
// Dans lib/config/ads_config.dart
static bool get adsEnabled => true;
```

**4. Vérifier le mode test**
- Activer "Test Mode" dans PropellerAds dashboard
- Les ads de test devraient s'afficher

**5. Vérifier les adblockers**
Désactiver temporairement AdBlock, uBlock Origin, etc.

### Erreur CORS

PropellerAds scripts sont chargés depuis `3nbf4.com`.
Si erreur CORS, c'est normal pour certains navigateurs.
Les ads s'afficheront quand même en production.

### Ads bloquées par AdBlockers

**C'est normal !** Les adblockers bloquent PropellerAds.
Environ 30-40% des utilisateurs utilisent des adblockers.

**Solution:** Pas de solution technique. C'est le modèle publicitaire.

---

## 💰 Monétisation

### Estimation Revenus

**Hypothèses:**
- 1000 utilisateurs actifs/jour
- 5 pages vues/utilisateur
- 2 impressions ad/page
- CPM = $2 (moyenne)

**Calcul:**
```
Impressions/jour = 1000 × 5 × 2 = 10,000
Revenue/jour = (10,000 / 1000) × $2 = $20/jour
Revenue/mois = $20 × 30 = $600/mois
```

**Facteurs d'optimisation:**
- Géolocalisation (US/EU = CPM plus élevé)
- Type de contenu
- Engagement utilisateur
- CTR (Click-Through Rate)

---

## 📈 Optimisations Futures

### A/B Testing
- Tester différentes positions de bannières
- Tester différentes tailles
- Tester fréquence des interstitials

### Formats Supplémentaires
- **Push Notifications**: Notifications web
- **Onclick**: Popunders au click
- **Interstitials**: Ads plein écran entre pages

### Stratégies
- Afficher interstitials après X messages envoyés
- Afficher push après X jours d'utilisation
- Afficher onclick sur actions non-critiques

---

## 📞 Support PropellerAds

- **Dashboard**: https://propellerads.com/
- **Support**: support@propellerads.com
- **Documentation**: https://propellerads.com/blog/category/guides/
- **FAQ**: https://propellerads.com/faq/

---

## ✅ Checklist Finale

### Configuration
- [x] Zone ID configuré (11034847)
- [x] Fichier sw.js placé dans web/
- [x] Widget PropellerAdsBanner créé
- [x] AdsConfig configuré
- [x] Code déployé sur GitHub

### Post-Déploiement
- [ ] Vérifier sw.js accessible sur Netlify
- [ ] Valider le site dans PropellerAds dashboard
- [ ] Tester affichage des ads
- [ ] Activer mode production dans PropellerAds
- [ ] Monitorer les premières impressions

### Monitoring
- [ ] Vérifier impressions quotidiennes
- [ ] Vérifier CTR
- [ ] Vérifier revenus
- [ ] Optimiser placements si besoin

---

## 🎉 Résumé

Votre configuration PropellerAds est **COMPLÈTE** ! 

**Ce qui a été fait:**
✅ Zone ID 11034847 configuré
✅ Fichier de vérification sw.js placé
✅ Widget PropellerAdsBanner prêt
✅ Configuration dans le code
✅ Documentation complète

**Prochaines étapes:**
1. ⏳ Attendre déploiement Netlify
2. ✅ Vérifier https://omnisms.netlify.app/sw.js
3. ✅ Valider le site dans PropellerAds dashboard
4. 📊 Commencer à générer des revenus !

---

**Bonne monétisation avec PropellerAds ! 💰**
