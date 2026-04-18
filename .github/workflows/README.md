# GitHub Actions Workflows

Ce dossier contient les workflows CI/CD pour OmniSMS Flutter Web.

## 🚀 Workflows Disponibles

### 1. `web-build.yml` - Build et Déploiement Web
**Déclenchement:** 
- Push sur `main` ou `feature/complete-backend-integration`
- Pull requests vers `main`
- Manuel via "Actions" tab

**Jobs:**
- **build-web**: Compile l'application Flutter Web en mode release
  - Setup Flutter 3.24.5
  - Install dependencies
  - Build web avec CanvasKit
  - Upload artifact (build/web/)
  
- **deploy-firebase**: Déploie sur Firebase Hosting (seulement sur main)
  - Download build artifact
  - Deploy vers https://omnisms-b98c5.web.app
  - Nécessite: `FIREBASE_SERVICE_ACCOUNT` secret

### 2. `tests.yml` - Tests et Qualité
**Déclenchement:**
- Push sur toutes les branches
- Pull requests vers `main`

**Jobs:**
- **analyze**: Analyse statique du code
  - Flutter analyze
  - Dart format check
  
- **test**: Tests unitaires et widgets
  - Run all tests
  - Generate coverage report
  - Upload to Codecov

## 🔐 Secrets Requis

Pour utiliser ces workflows, ajoutez ces secrets dans GitHub:

1. **FIREBASE_SERVICE_ACCOUNT**
   ```bash
   # Générer une clé de service Firebase
   firebase login
   firebase projects:list
   
   # Dans Firebase Console:
   # Project Settings > Service Accounts > Generate new private key
   # Copier le contenu JSON complet
   ```

2. **GITHUB_TOKEN** (automatique)
   - Fourni automatiquement par GitHub Actions

## 📝 Configuration

### Ajouter un Secret sur GitHub:
1. Aller sur https://github.com/emstronglezin-cmd/Omnisms-frontend
2. Settings > Secrets and variables > Actions
3. Click "New repository secret"
4. Nom: `FIREBASE_SERVICE_ACCOUNT`
5. Valeur: Contenu du JSON de la clé de service

### Déclencher Manuellement:
1. Aller dans l'onglet "Actions"
2. Sélectionner "Build and Deploy Flutter Web"
3. Click "Run workflow"
4. Choisir la branche
5. Click "Run workflow"

## 📊 Artifacts

Les builds sont sauvegardés comme artifacts pendant 30 jours:
- Nom: `web-build-{commit-sha}`
- Contenu: Dossier build/web/ complet
- Utilisation: Download depuis "Actions" tab > Workflow run > Artifacts section

## 🎯 Bonnes Pratiques

### Pour les Développeurs:
1. **Avant de push:**
   ```bash
   flutter analyze
   dart format .
   flutter test
   ```

2. **Feature branches:**
   - Créer depuis `main`: `git checkout -b feature/ma-fonctionnalite`
   - Les tests s'exécutent automatiquement sur chaque push

3. **Pull Requests:**
   - Tous les checks doivent passer (analyze + test)
   - Review le build artifact si nécessaire

### Pour le Déploiement:
1. **Staging** (feature branches):
   - Build uniquement, pas de déploiement
   - Télécharger l'artifact pour test local

2. **Production** (main):
   - Build + déploiement automatique sur Firebase
   - URL: https://omnisms-b98c5.web.app

## 🐛 Troubleshooting

### Build Failed
```bash
# Vérifier localement
flutter clean
flutter pub get
flutter build web --release
```

### Déploiement Failed
- Vérifier que `FIREBASE_SERVICE_ACCOUNT` est configuré
- Vérifier les permissions Firebase
- Tester localement: `firebase deploy --only hosting`

### Tests Failed
```bash
# Run tests localement
flutter test --coverage

# Voir les détails
flutter test --reporter expanded
```

## 📈 Statistiques

Voir les statistiques dans:
- Actions tab > Workflows
- Insights > Dependency graph
- Code > Insights > Community Standards

## 🔗 Liens Utiles

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Flutter CI/CD Guide](https://docs.flutter.dev/deployment/cd)
- [Firebase Hosting GitHub Action](https://github.com/FirebaseExtended/action-hosting-deploy)
- [Subosito Flutter Action](https://github.com/subosito/flutter-action)

---

**Dernière mise à jour:** 2026-04-14  
**Maintenu par:** OmniSMS Team
