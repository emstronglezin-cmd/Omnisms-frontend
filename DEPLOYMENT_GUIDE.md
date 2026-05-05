# 🚀 Guide de Déploiement Complet - OmniSMS Web PWA

## Vue d'Ensemble

Ce guide vous accompagne du push sur GitHub jusqu'au déploiement automatique sur Firebase Hosting.

## 📋 Prérequis

- [x] Code source prêt (layouts, PWA config, Firebase config)
- [x] Token GitHub: `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`
- [x] Project Firebase: `omnisms-b98c5`
- [ ] Service Account Firebase (à générer)

## 🎯 Étapes de Déploiement

### Étape 1: Vérification Locale

Avant de push, vérifier que tout compile :

```bash
cd /home/user/webapp

# Clean et test
flutter clean
flutter pub get
flutter analyze

# Test build local (optionnel mais recommandé)
flutter build web --debug  # Plus rapide pour test
```

### Étape 2: Commit et Push

```bash
# Status
git status

# Add tous les fichiers
git add .

# Commit
git commit -m "feat: 🌐 Add Flutter Web PWA + GitHub Actions workflows

- Created responsive layouts (mobile/web)
- Configured PWA (manifest.json, service worker)
- Added Firebase hosting config
- Created GitHub Actions workflows for CI/CD
- Dashboard adapted for web with stats cards
- Fixed CardTheme and PopupMenu issues"

# Push vers main
git push origin main
```

**OU** si vous êtes sur une feature branch:

```bash
# Push vers la feature branch
git push origin feature/complete-backend-integration

# Créer une Pull Request
# Aller sur https://github.com/emstronglezin-cmd/Omnisms-frontend
# Click "Compare & pull request"
# Merge après review
```

### Étape 3: Configuration GitHub Secrets

**IMPORTANT:** Sans ce secret, le déploiement ne fonctionnera pas!

1. **Générer la Clé Firebase**
   - Voir `.github/FIREBASE_SETUP.md` pour les instructions détaillées
   - Firebase Console > Project Settings > Service Accounts > Generate new private key

2. **Ajouter le Secret sur GitHub**
   ```
   https://github.com/emstronglezin-cmd/Omnisms-frontend/settings/secrets/actions
   ```
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: Contenu complet du JSON téléchargé

### Étape 4: Vérification du Workflow

Une fois le code pushé, le workflow se déclenche automatiquement.

**Suivre la Progression:**
1. Aller sur https://github.com/emstronglezin-cmd/Omnisms-frontend/actions
2. Sélectionner le dernier workflow run
3. Observer les jobs:
   - ✅ `build-web`: Compile l'application (~10-15 min)
   - ✅ `deploy-firebase`: Déploie sur Firebase (seulement si push sur main)

**Logs Utiles:**
```bash
# Voir les logs en temps réel
# Actions tab > Workflow run > Job > Step

# Exemple de sortie attendue:
✓ Flutter installed
✓ Dependencies installed
✓ Building web...
✓ Build completed (265.3MB)
✓ Artifact uploaded
✓ Deploying to Firebase...
✓ Deployed to https://omnisms-b98c5.web.app
```

### Étape 5: Télécharger le Build (Optionnel)

Si vous voulez tester le build avant déploiement:

1. **Télécharger l'Artifact**
   - Actions > Workflow run > Artifacts section
   - Download `web-build-{sha}`

2. **Tester Localement**
   ```bash
   # Extraire l'archive
   unzip web-build-xxxxx.zip -d build/web
   
   # Servir localement
   cd build/web
   python3 -m http.server 8000
   
   # Ouvrir http://localhost:8000
   ```

### Étape 6: Vérification du Déploiement

Une fois déployé, vérifier:

**URLs de Production:**
- 🌐 https://omnisms-b98c5.web.app
- 🌐 https://omnisms-b98c5.firebaseapp.com

**Tests à Effectuer:**

1. **PWA Installation**
   ```
   ✓ Attendre 3 secondes
   ✓ Prompt "Installer OmniSMS" apparaît
   ✓ Click "Installer"
   ✓ App installée sur bureau/home screen
   ✓ Icône OmniSMS visible
   ```

2. **Responsive Design**
   ```
   ✓ Mobile (<600px): Bottom navigation
   ✓ Web (≥600px): Sidebar + Header
   ✓ Transition fluide entre tailles
   ```

3. **Offline Mode**
   ```
   ✓ DevTools > Network > Offline
   ✓ Badge rouge "Mode hors ligne" apparaît
   ✓ Page reste accessible
   ✓ Service Worker actif
   ```

4. **Fonctionnalités**
   ```
   ✓ Login/Register fonctionne
   ✓ Dashboard affiche les stats
   ✓ Navigation sidebar fonctionnelle
   ✓ Messages/Contacts/Groupes accessibles
   ✓ Backend API répond (https://omnisms-backend.onrender.com)
   ```

## 🔄 Workflow CI/CD

### Comportement Automatique

**Sur Push vers `main`:**
```
1. Trigger workflow automatiquement
2. Build web en mode release
3. Upload artifact
4. Deploy sur Firebase
5. URLs de production mises à jour
```

**Sur Push vers feature branch:**
```
1. Trigger workflow automatiquement
2. Build web en mode release
3. Upload artifact
4. PAS de déploiement (seulement build)
```

**Sur Pull Request:**
```
1. Run tests (analyze + test)
2. Build web
3. Checks doivent passer avant merge
```

### Déclencher Manuellement

1. Aller sur Actions tab
2. Sélectionner "Build and Deploy Flutter Web"
3. Click "Run workflow"
4. Choisir la branche
5. Click "Run workflow"

## 📊 Monitoring

### GitHub Actions
```
https://github.com/emstronglezin-cmd/Omnisms-frontend/actions
```
- Voir l'historique des builds
- Télécharger les artifacts
- Consulter les logs

### Firebase Console
```
https://console.firebase.google.com/project/omnisms-b98c5/hosting
```
- Voir les déploiements
- Metrics (visits, bandwidth)
- Rollback si nécessaire

### Lighthouse Audit
```bash
# Test des performances
lighthouse https://omnisms-b98c5.web.app --view
```

## 🐛 Troubleshooting

### Build Failed on GitHub Actions

**Erreur: "Process exited with code 1"**
```bash
# Vérifier localement
flutter clean
flutter pub get
flutter build web --release

# Voir les erreurs de compilation
flutter analyze
```

**Erreur: "Out of memory"**
```yaml
# Le runner GitHub a 7GB RAM, normalement suffisant
# Si échec, contact GitHub Support ou utiliser self-hosted runner
```

### Deploy Failed

**Erreur: "Permission denied"**
```
Solution: Vérifier FIREBASE_SERVICE_ACCOUNT secret
- Régénérer la clé Firebase
- Réajouter le secret sur GitHub
```

**Erreur: "Project not found"**
```
Solution: Vérifier firebase.json
- projectId: omnisms-b98c5
- Project doit exister sur Firebase Console
```

### Site Not Loading

**Erreur: Page blanche**
```bash
# Vérifier la console browser (F12)
# Vérifier que les assets sont chargés
# Clear cache: Ctrl+Shift+R

# Vérifier firebase.json rewrites:
{
  "rewrites": [
    {
      "source": "**",
      "destination": "/index.html"
    }
  ]
}
```

## 📝 Commandes Utiles

```bash
# Local build
flutter build web --release

# Analyze
flutter analyze

# Test
flutter test

# Deploy manual (si workflow échoue)
firebase login
firebase use omnisms-b98c5
firebase deploy --only hosting

# Rollback
firebase hosting:channel:list
firebase hosting:rollback
```

## ✅ Checklist Finale

- [ ] Code pushé sur GitHub
- [ ] Workflow exécuté avec succès
- [ ] Secret Firebase configuré
- [ ] Build artifact généré
- [ ] Déploiement sur Firebase réussi
- [ ] Site accessible sur URLs de production
- [ ] PWA installation testée
- [ ] Responsive design vérifié
- [ ] Mode offline testé
- [ ] Backend API connecté

## 🎉 C'est Fait !

Votre application OmniSMS est maintenant **live en production** ! 🚀

**URLs:**
- 🌐 Production: https://omnisms-b98c5.web.app
- 📱 Backend API: https://omnisms-backend.onrender.com
- 💳 Abonnement: https://www.pay.moneyfusion.net/abonnement-a-omnisms-_1762539771460/

**Prochaines Étapes:**
1. Tests utilisateurs
2. Monitoring des performances
3. Feedback et itérations
4. Marketing et promotion

---

**Besoin d'aide?**
- GitHub Actions: https://github.com/emstronglezin-cmd/Omnisms-frontend/actions
- Firebase Console: https://console.firebase.google.com/project/omnisms-b98c5
- Documentation: Voir PWA_DOCUMENTATION.md
