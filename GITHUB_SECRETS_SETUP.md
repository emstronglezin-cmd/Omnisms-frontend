# 🔐 Configuration des Secrets GitHub

Pour que le workflow CI/CD fonctionne, vous devez configurer les secrets GitHub suivants:

## 📋 Étapes de Configuration

### 1. Générer la Clé de Service Firebase

```bash
# Méthode 1: Via Firebase CLI
firebase login
firebase init hosting:github

# Méthode 2: Via Console Firebase
# 1. Allez sur https://console.firebase.google.com/project/omnisms-b98c5/settings/serviceaccounts/adminsdk
# 2. Cliquez sur "Générer une nouvelle clé privée"
# 3. Téléchargez le fichier JSON
```

### 2. Ajouter le Secret sur GitHub

1. Allez sur votre repo: https://github.com/emstronglezin-cmd/Omnisms-frontend
2. Cliquez sur **Settings** (⚙️)
3. Dans le menu latéral gauche, cliquez sur **Secrets and variables** > **Actions**
4. Cliquez sur **New repository secret**
5. Remplissez:
   - **Name:** `FIREBASE_SERVICE_ACCOUNT`
   - **Value:** Collez tout le contenu du fichier JSON téléchargé

Le JSON devrait ressembler à:
```json
{
  "type": "service_account",
  "project_id": "omnisms-b98c5",
  "private_key_id": "abc123...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@omnisms-b98c5.iam.gserviceaccount.com",
  "client_id": "123456789...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/..."
}
```

6. Cliquez sur **Add secret**

### 3. Vérifier la Configuration

Une fois le secret ajouté:

1. Allez dans l'onglet **Actions** du repo
2. Vous devriez voir le workflow "🌐 Build & Deploy Web PWA"
3. Si un build est en cours, vérifiez qu'il n'y a pas d'erreur sur l'étape "Deploy to Firebase"

### 4. Tester le Workflow

Faites un commit pour déclencher le workflow:

```bash
git commit --allow-empty -m "test: trigger CI/CD"
git push origin main
```

Suivez le build dans l'onglet **Actions**.

## 📊 Autres Configurations Optionnelles

### Google Analytics 4

1. Créez une propriété GA4: https://analytics.google.com
2. Obtenez votre Measurement ID (format: `G-XXXXXXXXXX`)
3. Mettez à jour `lib/services/analytics_service.dart`:
   ```dart
   static const String _measurementId = 'G-VOTRE-ID-ICI';
   ```

### Firebase Cloud Messaging (FCM)

1. Allez sur Firebase Console > Project Settings > Cloud Messaging
2. Copiez votre **VAPID Key** (Web Push certificates)
3. Mettez à jour `lib/services/web_notification_service.dart`:
   ```dart
   _fcmToken = await _messaging.getToken(
     vapidKey: 'VOTRE-VAPID-KEY-ICI',
   );
   ```

## ✅ Vérification

Après configuration, le workflow devrait:

- ✅ Build réussi
- ✅ Tests passés
- ✅ Déploiement sur Firebase réussi
- ✅ Application accessible sur https://omnisms-b98c5.web.app

## 🐛 Dépannage

### Erreur: "Secret FIREBASE_SERVICE_ACCOUNT not found"
→ Le secret n'est pas configuré. Suivez les étapes ci-dessus.

### Erreur: "Permission denied on Firebase project"
→ Le compte de service n'a pas les permissions. Assurez-vous d'utiliser une clé de service avec rôle "Firebase Hosting Admin".

### Erreur: "Invalid JSON in service account"
→ Vérifiez que vous avez copié tout le JSON sans coupures.

## 📞 Support

Si vous rencontrez des problèmes:
1. Vérifiez les logs dans l'onglet Actions
2. Consultez la documentation Firebase: https://firebase.google.com/docs/hosting/github-integration
3. Contactez le support

---

**Note:** Le secret `GITHUB_TOKEN` est automatiquement fourni par GitHub Actions et n'a pas besoin d'être configuré manuellement.
