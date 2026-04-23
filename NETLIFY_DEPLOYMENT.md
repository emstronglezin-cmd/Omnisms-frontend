# 🚀 Guide de Déploiement Netlify - OmniSMS

## 📋 Vue d'ensemble

OmniSMS est maintenant prêt pour un déploiement sur Netlify avec :
- ✅ Configuration automatique
- ✅ Build Flutter Web intégré
- ✅ PWA complète
- ✅ Redirections SPA
- ✅ Headers de sécurité
- ✅ Cache optimisé

---

## 🎯 Méthode 1 : Déploiement via Interface Netlify (Recommandé)

### Étape 1 : Créer un compte Netlify
1. Aller sur https://www.netlify.com
2. S'inscrire avec GitHub
3. Autoriser l'accès au repository

### Étape 2 : Nouveau site depuis Git
1. Cliquer sur **"Add new site"** > **"Import an existing project"**
2. Sélectionner **GitHub**
3. Choisir le repo **Omnisms-frontend**
4. Branche : **main**

### Étape 3 : Configuration du Build

**Build settings:**
```
Build command: ./build.sh
Publish directory: build/web
```

**Environment variables** (optionnel):
```
FLUTTER_VERSION = 3.24.5
```

### Étape 4 : Déployer
1. Cliquer sur **"Deploy site"**
2. Attendre ~10-15 minutes (premier build)
3. Site accessible sur `https://[nom-du-site].netlify.app`

---

## 🎯 Méthode 2 : Déploiement via Netlify CLI

### Prérequis
```bash
npm install -g netlify-cli
netlify login
```

### Build Local
```bash
cd /path/to/Omnisms-frontend
./build.sh
```

### Déploiement
```bash
# Test (preview)
netlify deploy

# Production
netlify deploy --prod
```

---

## ⚙️ Configuration Netlify

### netlify.toml
Le fichier `netlify.toml` est déjà configuré avec:
- ✅ Commande de build
- ✅ Répertoire de publication
- ✅ Redirections SPA
- ✅ Headers de sécurité
- ✅ Cache optimisé

### Redirects (_redirects)
```
/*    /index.html   200
```
Permet le routing Flutter côté client.

### Headers (_headers)
- Sécurité: X-Frame-Options, X-XSS-Protection
- Cache: 1 an pour assets statiques
- PWA: Manifest et Service Worker

---

## 🔧 Variables d'Environnement (Optionnel)

Dans **Site settings > Environment variables**:

### Firebase (si vous voulez mettre à jour)
```
FIREBASE_API_KEY=AIzaSyD3Yur6Q5IvcDI_bC9YuLFNC4jvgEREtBQ
FIREBASE_PROJECT_ID=omnisms-b98c5
FIREBASE_MESSAGING_SENDER_ID=948236796279
```

### Google Analytics (si configuré)
```
GA4_MEASUREMENT_ID=G-XXXXXXXXXX
```

### FCM VAPID Key (si configuré)
```
FCM_VAPID_KEY=YOUR-VAPID-KEY-HERE
```

---

## 🌐 Custom Domain

### Ajouter un domaine personnalisé

1. **Site settings > Domain management**
2. Cliquer sur **"Add custom domain"**
3. Entrer votre domaine (ex: omnisms.com)
4. Configurer DNS:

```
Type    Name    Value
CNAME   www     [your-site].netlify.app
ALIAS   @       [your-site].netlify.app
```

### SSL automatique
Netlify active automatiquement HTTPS avec Let's Encrypt.

---

## 📊 Performance

### Optimisations incluses
- ✅ Cache 1 an pour assets
- ✅ Compression Gzip automatique
- ✅ CDN global Netlify
- ✅ Service Worker pour offline
- ✅ Lazy loading intégré

### Métriques attendues
- Performance: >90
- First Contentful Paint: <2s
- Time to Interactive: <3s
- Lighthouse PWA: 100

---

## 🔄 Déploiements Automatiques

### Depuis GitHub
Netlify déploie automatiquement quand vous push sur `main`:
```bash
git push origin main
```

### Preview Deployments
Chaque Pull Request génère un preview:
- URL unique
- Environnement isolé
- Tests avant merge

---

## 🧪 Tester le Déploiement

### 1. Vérifier PWA
```bash
# Ouvrir DevTools > Application
# Vérifier:
- Manifest détecté ✅
- Service Worker actif ✅
- Installable ✅
```

### 2. Tester Offline
```bash
# DevTools > Network > Offline
# Recharger la page
# App doit fonctionner ✅
```

### 3. Lighthouse Audit
```bash
npm install -g lighthouse
lighthouse https://your-site.netlify.app --view
```

### 4. Test Multi-navigateurs
- Chrome ✅
- Firefox ✅
- Safari ✅
- Edge ✅

---

## 🐛 Troubleshooting

### Build échoue
**Erreur:** "Flutter not found"
**Solution:** Netlify va installer Flutter automatiquement via build.sh

**Erreur:** "Out of memory"
**Solution:** Contacter Netlify support pour augmenter les ressources

### Page blanche après déploiement
**Cause:** Base href incorrect
**Solution:** Vérifier que `--base-href "/"` est dans build.sh

### PWA ne s'installe pas
**Cause:** HTTPS requis
**Solution:** Netlify active HTTPS par défaut, attendre propagation DNS

### Service Worker ne fonctionne pas
**Cause:** Cache navigateur
**Solution:** 
```bash
# DevTools > Application > Storage > Clear site data
```

---

## 🔒 Sécurité

### Headers configurés
```
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: no-referrer-when-downgrade
```

### HTTPS
- Activé automatiquement
- Certificat Let's Encrypt
- Renouvellement automatique

---

## 📈 Monitoring

### Netlify Analytics
- Activation: Site settings > Analytics
- Métriques:
  - Pages vues
  - Visiteurs uniques
  - Temps de chargement
  - Erreurs 404

### Google Analytics 4
Déjà intégré dans le code:
- `lib/services/analytics_service.dart`
- Tracking automatique des événements

---

## 💰 Coûts

### Plan Gratuit
- ✅ 100GB bandwidth/mois
- ✅ 300 build minutes/mois
- ✅ SSL gratuit
- ✅ CDN global
- ✅ Formulaires (100/mois)

**Suffisant pour:**
- ~10,000 visiteurs/mois
- Builds illimités
- Domaine personnalisé

### Plan Pro ($19/mois)
- 400GB bandwidth
- 25,000 build minutes
- Meilleur support

---

## 🎯 Checklist Post-Déploiement

- [ ] Site accessible sur https://[site].netlify.app
- [ ] PWA installable (attendre 3s, cliquer "Installer")
- [ ] Mode offline fonctionne
- [ ] Notifications activées
- [ ] Bouton "S'abonner" redirige vers GitHub Pages
- [ ] Analytics trackant les événements
- [ ] Lighthouse score >90
- [ ] Domaine personnalisé configuré (optionnel)

---

## 📞 Support

### Documentation Netlify
- https://docs.netlify.com
- https://docs.netlify.com/configure-builds/overview/

### Flutter Web
- https://docs.flutter.dev/platform-integration/web

### Issues
- GitHub: https://github.com/emstronglezin-cmd/Omnisms-frontend/issues

---

## 🚀 Commandes Rapides

```bash
# Build local
./build.sh

# Deploy preview
netlify deploy

# Deploy production
netlify deploy --prod

# Logs
netlify watch

# Open admin
netlify open:admin

# Open site
netlify open:site
```

---

**Version:** 2.2.0+4  
**Status:** ✅ Production Ready  
**Platform:** Netlify  
**Last Updated:** 2026-04-18
