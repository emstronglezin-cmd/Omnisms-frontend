# 🚀 Déploiement Vercel - OmniSMS

## ✅ Configuration Terminée

Votre projet est maintenant configuré pour Vercel !

---

## 📋 Fichiers Créés

### 1. `vercel.json` (1.9KB)
Configuration principale Vercel :
- Build command: `flutter build web --release`
- Output directory: `build/web`
- Routes (SPA, service workers, cache)
- Headers de sécurité

### 2. `vercel-build.sh` (1.3KB)
Script de build automatique :
- Installation Flutter SDK
- Dependencies
- Build web release

### 3. `.vercelignore` (482 bytes)
Fichiers à ignorer lors du deploy

---

## 🚀 Déploiement sur Vercel

### Option 1: Via Vercel CLI (Recommandé)

#### Installation
```bash
npm install -g vercel
```

#### Login
```bash
vercel login
```

#### Déployer
```bash
# Dans le dossier du projet
cd /home/user/webapp

# Premier déploiement
vercel

# Production
vercel --prod
```

---

### Option 2: Via GitHub (Auto-Deploy)

#### Étapes:
1. **Push sur GitHub** (déjà fait)
2. **Aller sur** https://vercel.com
3. **Cliquer** "Add New Project"
4. **Importer** depuis GitHub
5. **Sélectionner** omnisms-frontend
6. **Configurer:**
   - Framework Preset: **Other**
   - Build Command: **(laisser auto-détecté)**
   - Output Directory: `build/web`
7. **Deploy!**

Vercel détectera automatiquement `vercel.json` et utilisera la configuration.

---

### Option 3: Via GitHub Token (Votre Token)

Votre token: `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`

⚠️ **Attention:** Ce token doit être utilisé avec précaution.

**Configuration:**
```bash
# Login avec token
vercel login --token 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

# Deploy
vercel --prod
```

---

## ⚙️ Configuration Automatique

### Vercel Auto-Detection

Vercel va:
1. ✅ Détecter `vercel.json`
2. ✅ Installer Flutter SDK (via `installCommand`)
3. ✅ Exécuter `flutter pub get`
4. ✅ Builder `flutter build web --release`
5. ✅ Déployer le contenu de `build/web/`

### URLs Générées

**Preview (branches):**
```
https://omnisms-<branch>-<hash>.vercel.app
```

**Production (main):**
```
https://omnisms.vercel.app
ou
https://your-custom-domain.com
```

---

## 🔍 Vérifications Post-Deploy

### 1. Service Workers
```
https://omnisms.vercel.app/sw.js
https://omnisms.vercel.app/firebase-messaging-sw.js
```

### 2. Manifest PWA
```
https://omnisms.vercel.app/manifest.json
```

### 3. PropellerAds Verification
```
https://omnisms.vercel.app/sw.js
# Devrait afficher le service worker PropellerAds
```

---

## 📊 Avantages Vercel vs Netlify

### ✅ Vercel
- ⚡ **Plus rapide** (Edge Network global)
- 🚀 **CDN ultra-performant**
- 🔄 **Rollbacks instantanés**
- 📈 **Analytics intégrés**
- 🆓 **100GB bandwidth gratuit**
- 🌍 **Edge Functions** (serverless)
- 🔒 **SSL automatique**
- 🎯 **Preview deployments** pour chaque branch

### Netlify (ancien)
- ✅ Simplicité
- ⏱️ Build plus lent
- 💰 Moins de bandwidth gratuit

---

## 🐛 Troubleshooting

### Build Échoue

**Problème:** Flutter SDK installation échoue

**Solution:**
```json
// Dans vercel.json, vérifier installCommand
"installCommand": "if [ ! -d \"flutter\" ]; then wget -q ... fi"
```

---

### Service Workers Non Accessibles

**Problème:** 404 sur `/sw.js`

**Solution:**
Vérifier que `web/sw.js` existe et est copié dans le build.

---

### Routes ne Fonctionnent Pas

**Problème:** Rafraîchissement page donne 404

**Solution:**
```json
// Dans vercel.json
{
  "src": "/(.*)",
  "dest": "/index.html"
}
```

---

## 📈 Performance

### Métriques Cibles

| Métrique | Vercel | Netlify |
|----------|--------|---------|
| First Byte | <100ms | <200ms |
| CDN Nodes | 70+ | 40+ |
| SSL Setup | Instant | Instant |
| Build Time | ~5min | ~8min |

---

## 🔒 Variables d'Environnement

### Configuration Vercel Dashboard

1. **Aller** dans votre projet Vercel
2. **Settings** → **Environment Variables**
3. **Ajouter:**
   - `FLUTTER_VERSION`: `3.24.5`
   - `ADS_ENABLED`: `true`
   - (autres si besoin)

---

## 🎯 Checklist Déploiement

### Pré-Deploy
- [x] Start.io supprimé
- [x] PropellerAds configuré
- [x] vercel.json créé
- [x] .vercelignore créé
- [x] vercel-build.sh créé
- [x] Code pushé sur GitHub

### Deploy
- [ ] Login Vercel
- [ ] Import GitHub repo
- [ ] Configure project
- [ ] Deploy
- [ ] Vérifier URL production

### Post-Deploy
- [ ] Tester app complète
- [ ] Vérifier sw.js accessible
- [ ] Valider PropellerAds
- [ ] Configurer custom domain (optionnel)
- [ ] Activer Analytics Vercel

---

## 💡 Custom Domain

### Ajouter un Domaine

1. **Dashboard Vercel** → Votre projet
2. **Settings** → **Domains**
3. **Add Domain**: `omnisms.com` (exemple)
4. **Configurer DNS** chez votre registrar:
   ```
   A Record: 76.76.21.21
   CNAME: cname.vercel-dns.com
   ```
5. ✅ Vérification automatique

---

## 🎉 Résumé

### ✅ Configuration Complète

**Supprimé:**
- ❌ Start.io (complètement supprimé)
- ❌ Netlify configuration
- ❌ netlify.toml
- ❌ build.sh

**Ajouté:**
- ✅ vercel.json (config complète)
- ✅ vercel-build.sh (script build)
- ✅ .vercelignore (optimisation)
- ✅ PropellerAds (déjà configuré)

### 🚀 Prêt pour Vercel

Votre projet est **100% prêt** pour être déployé sur Vercel !

**Commande unique:**
```bash
vercel --prod
```

---

**Bon déploiement sur Vercel ! 🚀**
