# 🚀 Guide de Lancement — AI Sales Agency V5

## Vue d'ensemble

AI Sales Agency est un système d'automatisation commerciale complet qui :
- **Prospecte** automatiquement (Google Maps, LinkedIn, simulation)
- **Qualifie** les leads via un algorithme de scoring (0-100)
- **Crée** des emails ultra-personnalisés par secteur
- **Envoie** via Gmail OAuth2 avec protection anti-spam
- **Suit** les réponses et adapte le pipeline
- **Génère** des rapports quotidiens

---

## 📋 ÉTAPE 1 — Configuration Supabase

### 1.1 Créer le projet Supabase
1. Allez sur [supabase.com](https://supabase.com)
2. Créez un nouveau projet
3. Notez votre URL et vos clés API

### 1.2 Exécuter le schéma SQL
1. Dans Supabase → **SQL Editor**
2. Copiez le contenu de `scripts/01_supabase_schema.sql`
3. Cliquez **Run**
4. Vérifiez la création des 13 tables :
   ```
   ✅ leads, clients, agents, agent_memory, workflows,
   ✅ pipeline_transitions, strategies, emails, activites,
   ✅ ventes, tickets, kpi_quotidiens, configuration
   ```

### 1.3 Récupérer vos clés
Dans Supabase → **Settings → API** :
- `SUPABASE_URL`: `https://xxx.supabase.co`
- `SUPABASE_ANON_KEY`: clé anon publique
- `SUPABASE_SERVICE_KEY`: clé service (secret)

---

## 📧 ÉTAPE 2 — Configuration Gmail OAuth2

### 2.1 Lancer l'authentification
```bash
cd ai-sales-agency
node gmail/auth.js
```

### 2.2 Autoriser dans le navigateur
1. Copiez l'URL affichée dans le terminal
2. Ouvrez dans votre navigateur
3. Connectez-vous avec votre compte Gmail
4. Autorisez l'accès
5. Copiez le code affiché

### 2.3 Sauvegarder le token
Le script affichera :
```
GMAIL_REFRESH_TOKEN=1//0gXxx...
GMAIL_SENDER_EMAIL=votre@gmail.com
```

Ajoutez ces lignes dans votre `.env`.

### 2.4 Alternative — Via le Dashboard
1. Lancez le serveur : `npm start`
2. Allez sur `http://localhost:3001`
3. Onglet **Actions** → **Connecter Gmail**
4. Suivez les instructions

---

## ⚙️ ÉTAPE 3 — Fichier de configuration

### 3.1 Créer le fichier .env
```bash
cp .env.example .env
```

### 3.2 Remplir les variables
```env
# OBLIGATOIRE — Supabase
SUPABASE_URL=https://votre-projet.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# OBLIGATOIRE — Gmail (après node gmail/auth.js)
GMAIL_REFRESH_TOKEN=1//0gXxx...
GMAIL_SENDER_EMAIL=votre@gmail.com
GMAIL_SENDER_NAME=Votre Agence Web

# OPTIONNEL — OpenAI (améliore les emails)
OPENAI_API_KEY=sk-...

# OPTIONNEL — Google Maps (prospection réelle)
GOOGLE_MAPS_API_KEY=AIzaXXX...

# SÉCURITÉ — Commencer en mode test!
TEST_MODE=true
MAX_EMAILS_PER_DAY=10
MIN_DELAY_DAYS=7
```

---

## 🚀 ÉTAPE 4 — Lancement

### 4.1 Installer les dépendances
```bash
cd ai-sales-agency
npm install
```

### 4.2 Lancer le serveur
```bash
npm start
```

### 4.3 Accéder au dashboard
Ouvrez : **http://localhost:3001**

---

## 🧪 ÉTAPE 5 — Premier test (10 prospects)

### Option A — Via le Dashboard
1. Onglet **Actions** → **Premier test réel**
2. Attendez la fin (2-3 minutes)
3. Vérifiez onglets **Leads** et **Emails**

### Option B — Via le terminal
```bash
node scripts/test_pipeline.js
```

### Ce qui se passe :
1. **Prospecteur IA** → Trouve 10 entreprises (restaurant, commerce, artisan à Lyon)
2. **Analyste IA** → Score chaque lead sur 100 points
3. **Strategist IA** → Crée un email personnalisé pour chaque lead qualifié (score ≥ 50)
4. **Commercial IA** → Envoie les emails (ou simule si TEST_MODE=true)
5. **Manager IA** → Génère le rapport

---

## 🔄 ÉTAPE 6 — Mode automatique

### Activer le mode auto
Dans `.env` :
```env
# ATTENTION: désactiver TEST_MODE avant d'activer le mode auto en production!
TEST_MODE=false
```

### Lancer via API
```bash
curl -X POST http://localhost:3001/api/pipeline/test
```

### Scheduler quotidien (optionnel)
Ajoutez dans `server.js` :
```javascript
const cron = require('node-cron');
// Lancer le pipeline chaque jour à 9h
cron.schedule('0 9 * * 1-5', () => pipeline.lancerModeAuto());
```

---

## 📊 ÉTAPE 7 — Surveillance

### Dashboard KPI
- Leads: total, qualifiés, taux
- Emails: envoyés, réponses, taux de réponse
- Ventes: signées, CA total
- Clients: actifs, satisfaction

### Rapport Manager (quotidien)
Onglet **Rapport Manager** → **Générer rapport**

Contient :
- KPI du jour
- Alertes détectées
- Recommandations
- Actions suggérées

### API de monitoring
```bash
# Statut global
curl http://localhost:3001/api/status

# KPI dashboard
curl http://localhost:3001/api/kpi

# Statut pipeline
curl http://localhost:3001/api/pipeline/status
```

---

## 🔧 Configuration avancée

### Modifier les quotas email
Via le Dashboard → **Configuration** :
- Max emails/jour (défaut: 10)
- Délai avant relance (défaut: 7 jours)
- Max relances (défaut: 1)
- Score minimum (défaut: 50/100)

Ou via SQL Supabase :
```sql
UPDATE configuration SET valeur = '20' WHERE cle = 'email.max_par_jour';
UPDATE configuration SET valeur = '14' WHERE cle = 'email.delai_relance_jours';
```

### Ajouter des secteurs cibles
```sql
UPDATE configuration
SET valeur = '["restaurant","commerce","artisan","hotel","medecin","dentiste","avocat","pharmacie"]'
WHERE cle = 'prospecting.secteurs_cibles';
```

### Changer le modèle IA
Dans `.env` :
```env
OPENAI_MODEL=gpt-4-turbo-preview
```

---

## 🛡️ Protection anti-spam

Le système inclut automatiquement :

| Protection | Valeur par défaut |
|-----------|-------------------|
| Max emails/jour | 10 |
| Délai entre contacts | 7 jours |
| Max relances | 1 par prospect |
| Personnalisation | Unique pour chaque prospect |
| Déduplication | Email unique par prospect |
| Désinscription | Arrêt automatique |
| Après réponse | Email arrêté automatiquement |

### Vérifier avant envoi
```bash
# Via SQL Supabase
SELECT can_send_email('uuid-du-lead');
```

---

## 🔗 Architecture technique

```
┌─────────────┐
│  DASHBOARD  │  http://localhost:3001
│  Express    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────┐
│              PIPELINE                        │
│                                             │
│  Manager V4 ──────────────────────────┐    │
│       ↓                               │    │
│  Prospecteur V3 → Leads Supabase      │    │
│       ↓                               │    │
│  Analyste V2 → Score + Qualification  │    │
│       ↓                               │    │
│  Strategist V1 → Email personnalisé   │    │
│       ↓                               │    │
│  Commercial V1 → Gmail OAuth2         │    │
│       ↓                               │    │
│  Support V1 → Onboarding clients ────┘    │
└─────────────────────────────────────────────┘
       │
       ▼
┌─────────────┐    ┌─────────────┐
│  SUPABASE   │    │   GMAIL     │
│  13 tables  │    │  OAuth2     │
│  RLS + RPC  │    │  API v3     │
└─────────────┘    └─────────────┘
```

---

## 🐛 Résolution de problèmes

### "Supabase non configuré"
```bash
# Vérifiez votre .env
cat .env | grep SUPABASE
# URL doit commencer par https://xxx.supabase.co
```

### "Gmail: pas de token"
```bash
node gmail/auth.js
# Suivez les instructions pour obtenir le refresh token
```

### "Quota journalier atteint"
```bash
# Vérifier combien d'emails ont été envoyés
curl http://localhost:3001/api/emails?direction=envoye
# Modifier le quota
# Dashboard → Configuration → Max emails/jour
```

### "Lead non qualifié"
Le score minimum est 50/100. Un lead est non qualifié si :
- Pas d'email de contact
- Score < 50 (pas assez d'opportunité détectée)

### Mode test activé par erreur
```env
# Dans .env
TEST_MODE=false
# Relancer: npm start
```

---

## 📈 Objectifs commerciaux

| Métrique | Objectif Semaine 1 | Objectif Mois 1 |
|---------|-------------------|-----------------|
| Leads prospectés | 50 | 200 |
| Taux qualification | 50% | 60% |
| Emails envoyés | 25 | 100 |
| Taux de réponse | 5-15% | 10-20% |
| RDV obtenus | 2-5 | 10-20 |
| Propositions | 1-3 | 5-10 |
| Ventes | 0-1 | 2-5 |
| CA | 0-1500€ | 3000-7500€ |

---

## 📞 Support et évolutions

### Fichiers clés à modifier
- `config/index.js` — Configuration globale
- `agents/strategist.js` — Templates emails
- `agents/analyste.js` — Algorithme de scoring
- `agents/prospecteur.js` — Sources de prospection
- `dashboard/index.html` — Interface visuelle

### Commandes utiles
```bash
# Tester le pipeline
npm test

# Vérifier les logs
npm start 2>&1 | tee logs.txt

# Forcer un scoring de tous les leads
curl -X POST http://localhost:3001/api/pipeline/test

# Générer le rapport manuellement
curl -X POST http://localhost:3001/api/rapport
```

---

*Documentation générée automatiquement — AI Sales Agency V5*
