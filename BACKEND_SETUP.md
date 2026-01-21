# Configuration Backend pour OmniSMS

## Vue d'ensemble

Votre application Flutter OmniSMS est maintenant configurée pour se connecter à un backend. Voici comment configurer et utiliser votre backend.

## Structure de l'API Backend

Votre backend doit exposer les endpoints suivants :

### 1. Contacts
- **GET** `/api/contacts`
- **Réponse** : `["Alice", "Bob", "Charlie"]`

### 2. Messages
- **GET** `/api/messages?contact={contactName}`
- **Réponse** :
```json
[
  {
    "content": "Salut, comment ça va ?",
    "sender": "Alice",
    "timestamp": "2024-01-15T10:30:00.000Z",
    "isMe": false
  }
]
```

### 3. Envoi de message
- **POST** `/api/messages/send`
- **Body** :
```json
{
  "contact": "Alice",
  "content": "Bonjour !",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### 4. WebSocket
- **URL** : `ws://localhost:3000/ws`
- **Messages reçus** :
```json
{
  "content": "Message reçu en temps réel !",
  "sender": "Alice",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "isMe": false
}
```

## Configuration

### 1. URL du backend configurée

Votre backend est configuré pour l'adresse : `http://10.0.2.2:5000`

Cette adresse est déjà configurée dans `lib/config/api_config.dart` :
```dart
class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:5000';
  static const String wsUrl = 'ws://10.0.2.2:5000/ws';
  // ...
}
```

**Note** : `10.0.2.2` est l'adresse IP spéciale pour accéder au localhost de la machine hôte depuis un émulateur Android.

### 2. Permissions Android configurées

Les permissions réseau sont déjà configurées dans `android/app/src/main/AndroidManifest.xml` :
- `INTERNET` : Pour les requêtes HTTP
- `ACCESS_NETWORK_STATE` : Pour vérifier l'état du réseau
- `usesCleartextTraffic="true"` : Pour autoriser HTTP (non-HTTPS)

### 3. Installer les dépendances

```bash
flutter pub get
```

### 4. Exemple de serveur Node.js/Express pour votre backend

```javascript
const express = require('express');
const WebSocket = require('ws');
const http = require('http');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.use(express.json());

// CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

// Endpoints API
app.get('/api/contacts', (req, res) => {
  res.json(['Alice', 'Bob', 'Charlie']);
});

app.get('/api/messages', (req, res) => {
  const contact = req.query.contact;
  // Retourner les messages pour ce contact
  res.json([]);
});

app.post('/api/messages/send', (req, res) => {
  const { contact, content, timestamp } = req.body;
  // Traiter l'envoi du message
  res.json({ success: true });
});

// WebSocket
wss.on('connection', (ws) => {
  console.log('Client connecté');
  
  // Envoyer un message de test toutes les 10 secondes
  setInterval(() => {
    ws.send(JSON.stringify({
      content: 'Message reçu en temps réel !',
      sender: 'Alice',
      timestamp: new Date().toISOString(),
      isMe: false
    }));
  }, 10000);
});

server.listen(5000, () => {
  console.log('Serveur démarré sur le port 5000');
});
```

## Fonctionnalités implémentées

✅ **Communication HTTP** : Récupération des contacts et messages  
✅ **WebSocket** : Messages en temps réel  
✅ **Gestion d'erreurs** : Affichage des erreurs de connexion  
✅ **États de chargement** : Indicateurs visuels pendant les requêtes  
✅ **Fallback** : Données par défaut en cas d'erreur de connexion  
✅ **Architecture modulaire** : Services séparés pour la logique API  

## Test de Connexion

Votre application Flutter inclut maintenant un **écran de test de connexion** :

1. **Lancez l'application** sur votre émulateur Android
2. **Appuyez sur l'icône réseau** (🌐) dans la barre d'outils de l'écran Contacts
3. **Cliquez sur "Tester la Connexion"** pour vérifier tous les endpoints
4. **Vérifiez les résultats** - tous les tests doivent être verts

## Prochaines étapes

1. **Démarrez votre backend** sur le port 5000
2. **Testez la connexion** avec l'écran de test intégré
3. **Vérifiez que tous les endpoints** répondent correctement
4. **Intégrez Twilio** pour l'envoi de vrais SMS
5. **Ajoutez l'authentification** si nécessaire

## Dépannage

- **Backend non accessible** : Vérifiez que votre serveur est démarré sur le port 5000
- **Erreur de connexion** : Utilisez l'écran de test intégré pour diagnostiquer
- **CORS errors** : Ajoutez les headers CORS dans votre backend
- **Émulateur Android** : Assurez-vous d'utiliser `10.0.2.2` et non `localhost`
- **Permissions** : Vérifiez que les permissions réseau sont accordées

### Endpoints requis par votre backend :

```
GET  /api/contacts              - Liste des contacts
GET  /api/messages?contact=xxx  - Messages d'un contact
POST /api/messages/send         - Envoyer un message
WS   /ws                        - WebSocket pour messages temps réel
```
