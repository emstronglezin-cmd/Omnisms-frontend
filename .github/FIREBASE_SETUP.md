# 🔐 Configuration des Secrets Firebase pour GitHub Actions

## Étape 1: Générer une Clé de Service Firebase

### Via Firebase Console (Recommandé):

1. **Aller sur Firebase Console**
   ```
   https://console.firebase.google.com/project/omnisms-b98c5
   ```

2. **Accéder aux Paramètres du Projet**
   - Click sur l'icône ⚙️ (Settings)
   - Sélectionner "Project settings"

3. **Onglet Service Accounts**
   - Click sur "Service accounts" tab
   - Click sur "Generate new private key"
   - ⚠️ **IMPORTANT:** Confirmer en cliquant "Generate key"
   - Un fichier JSON sera téléchargé (ex: `omnisms-b98c5-firebase-adminsdk-xxxxx.json`)

### Via Firebase CLI (Alternative):

```bash
# Login
firebase login

# Sélectionner le projet
firebase use omnisms-b98c5

# Générer la clé (nécessite droits admin)
firebase projects:list
```

## Étape 2: Ajouter le Secret sur GitHub

1. **Aller sur le Repository GitHub**
   ```
   https://github.com/emstronglezin-cmd/Omnisms-frontend
   ```

2. **Accéder aux Settings**
   - Click sur "Settings" (tab en haut)
   - Dans le menu latéral gauche:
     - Secrets and variables > Actions

3. **Créer un Nouveau Secret**
   - Click sur "New repository secret"
   - **Name:** `FIREBASE_SERVICE_ACCOUNT`
   - **Value:** Copier-coller **TOUT LE CONTENU** du fichier JSON téléchargé
   
   Exemple du contenu JSON:
   ```json
   {
     "type": "service_account",
     "project_id": "omnisms-b98c5",
     "private_key_id": "abc123...",
     "private_key": "-----BEGIN PRIVATE KEY-----\n...",
     "client_email": "firebase-adminsdk-xxxxx@omnisms-b98c5.iam.gserviceaccount.com",
     "client_id": "...",
     "auth_uri": "https://accounts.google.com/o/oauth2/auth",
     "token_uri": "https://oauth2.googleapis.com/token",
     "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
     "client_x509_cert_url": "..."
   }
   ```

4. **Sauvegarder**
   - Click sur "Add secret"
   - ✅ Le secret est maintenant configuré!

## Étape 3: Vérifier la Configuration

### Test Local (Optionnel):

```bash
# Export le secret (pour test)
export FIREBASE_SERVICE_ACCOUNT='<contenu-json>'

# Test du déploiement
firebase deploy --only hosting --token "$(cat firebase-token.txt)"
```

### Test sur GitHub Actions:

1. **Push du code avec les workflows**
   ```bash
   git add .github/workflows/
   git commit -m "ci: Add GitHub Actions workflows"
   git push origin main
   ```

2. **Vérifier l'Exécution**
   - Aller sur https://github.com/emstronglezin-cmd/Omnisms-frontend/actions
   - Sélectionner le workflow "Build and Deploy Flutter Web"
   - Vérifier que le job "deploy-firebase" s'exécute sans erreur

## Étape 4: Permissions Firebase

Assurez-vous que le compte de service a les bonnes permissions:

1. **Dans Firebase Console:**
   - Settings > Users and permissions
   - Vérifier que le service account a le rôle "Editor" ou "Firebase Admin"

2. **Dans Google Cloud Console:**
   ```
   https://console.cloud.google.com/iam-admin/iam?project=omnisms-b98c5
   ```
   - Le service account doit avoir:
     - `Firebase Hosting Admin`
     - `Service Account User`

## 🔒 Sécurité

### ⚠️ À NE JAMAIS FAIRE:
- ❌ Ne JAMAIS commit la clé JSON dans Git
- ❌ Ne JAMAIS partager la clé publiquement
- ❌ Ne JAMAIS afficher la clé dans les logs

### ✅ Bonnes Pratiques:
- ✅ Stocker uniquement dans GitHub Secrets
- ✅ Utiliser des clés séparées pour staging/production
- ✅ Révoquer les anciennes clés régulièrement
- ✅ Monitorer l'usage via Firebase Console

### Ajouter à .gitignore:
```bash
# Dans .gitignore
*-firebase-adminsdk-*.json
firebase-token.txt
.firebase/
```

## 🐛 Troubleshooting

### Erreur: "Permission denied"
```
Solution: Vérifier les permissions IAM du service account
```

### Erreur: "Invalid service account"
```
Solution: 
1. Vérifier que le JSON est complet (avec BEGIN/END PRIVATE KEY)
2. Pas d'espaces ou retours à la ligne en trop
3. Regenerer une nouvelle clé si nécessaire
```

### Erreur: "Project not found"
```
Solution: Vérifier que project_id dans le JSON = "omnisms-b98c5"
```

## 📝 Template de Secret GitHub

Pour ajouter le secret, copier-coller ce template dans GitHub Secrets:

**Name:** `FIREBASE_SERVICE_ACCOUNT`

**Value:**
```json
{
  "type": "service_account",
  "project_id": "omnisms-b98c5",
  "private_key_id": "VOTRE_PRIVATE_KEY_ID",
  "private_key": "-----BEGIN PRIVATE KEY-----\nVOTRE_PRIVATE_KEY\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@omnisms-b98c5.iam.gserviceaccount.com",
  "client_id": "VOTRE_CLIENT_ID",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "VOTRE_CERT_URL"
}
```

## ✅ Checklist Finale

- [ ] Clé de service Firebase générée
- [ ] Secret `FIREBASE_SERVICE_ACCOUNT` ajouté sur GitHub
- [ ] Permissions IAM vérifiées
- [ ] `.gitignore` mis à jour
- [ ] Test du workflow réussi
- [ ] Déploiement automatique fonctionne

---

**Besoin d'aide?** 
- Firebase Console: https://console.firebase.google.com
- GitHub Actions: https://github.com/emstronglezin-cmd/Omnisms-frontend/actions
