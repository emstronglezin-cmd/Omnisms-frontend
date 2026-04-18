# 🚀 Guide d'Implémentation - OmniSMS Refactorisation Complète

## 📋 Vue d'ensemble

Cette refactorisation transforme OmniSMS en une application Flutter moderne entièrement connectée au backend.

**Branche**: `feature/complete-backend-integration`  
**Version**: 2.2.0  
**Date**: 2026-03-06

---

## ✅ Travail Réalisé (Phase 1)

### 1. Architecture Propre Créée

#### Models (`lib/models/`)
- ✅ `user_model.dart` - Modèle utilisateur avec JSON parsing
- ✅ `contact_model.dart` - Modèle contact avec initiales et display name
- ✅ `message_model.dart` - Modèle message (text, voice, image, video, file)
- ✅ `group_model.dart` - Modèle groupe
- ✅ `models.dart` - Export barrel file

**Fonctionnalités des models**:
- Parsing JSON depuis le backend
- Serialization vers JSON
- Méthodes `copyWith` pour immutabilité
- Getters utilitaires (initials, displayName, etc.)

#### Services (`lib/services/`)
- ✅ `auth_service.dart` - Authentification complète
  - Register (inscription)
  - Login (connexion)
  - getCurrentUser (profil)
  - updateProfile (mise à jour)
  - Token management (sauvegarde/récupération)
  - Logout

- ✅ `contacts_service.dart` - Gestion des contacts
  - requestContactsPermission (permissions)
  - getPhoneContacts (contacts du téléphone)
  - syncContacts (synchronisation avec backend)
  - getContacts (récupération depuis backend)
  - searchContacts (recherche)

- ✅ `messaging_service.dart` - Messagerie temps réel
  - sendTextMessage (envoi texte)
  - sendVoiceMessage (envoi vocal avec fichier)
  - getMessages (récupération)
  - reactToMessage (emoji reaction)
  - deleteMessage (suppression)
  - transcribeVoiceMessage (transcription)
  - connectWebSocket (connexion temps réel)
  - disconnectWebSocket
  - markAsRead (marquer comme lu)

- ✅ `groups_service.dart` - Gestion des groupes
  - getGroups
  - createGroup
  - updateGroup
  - addMember / removeMember
  - deleteGroup
  - getGroupMessages
  - sendGroupMessage

- ✅ `settings_service.dart` - Paramètres et statistiques
  - getStatistics (stats utilisateur)
  - Notifications enabled
  - Sounds enabled
  - Alerts enabled
  - Theme mode (light/dark/system)
  - getSubscriptionStatus

- ✅ `audio_recording_service.dart` - Enregistrement audio
  - requestPermission
  - startRecording
  - stopRecording
  - cancelRecording
  - recordingDuration (getter)

#### Providers (`lib/providers/`)
- ✅ `auth_provider.dart` - State management authentification
  - register / login / logout
  - updateProfile
  - currentUser (reactive)
  - isLoggedIn / isLoading / error

- ✅ `theme_provider.dart` - State management thème
  - themeMode (light / dark / system)
  - setThemeMode / toggleTheme
  - lightTheme / darkTheme (Material 3)

---

## 🔧 Configuration Backend

### API Endpoints (`lib/config/api_config.dart`)

**Base URL**: `http://51.15.89.72:5000`  
**WebSocket**: `ws://51.15.89.72:5000/ws`

**Endpoints disponibles**:
```dart
/api/auth/register          POST   - Inscription
/api/auth/login             POST   - Connexion
/api/auth/me                GET    - Profil utilisateur
/api/auth/profile           PUT    - Mise à jour profil

/api/contacts               GET    - Liste contacts
/api/contacts/sync          POST   - Sync contacts
/api/contacts/search        GET    - Recherche

/api/messages               GET    - Liste messages
/api/messages/send          POST   - Envoyer message
/api/messages/:id/react     POST   - Réagir (emoji)
/api/messages/:id/read      POST   - Marquer lu
/api/messages/:id           DELETE - Supprimer

/api/groups                 GET    - Liste groupes
/api/groups                 POST   - Créer groupe
/api/groups/:id             PUT    - Modifier groupe
/api/groups/:id             DELETE - Supprimer groupe
/api/groups/:id/members     POST   - Ajouter membre
/api/groups/:id/members/:uid DELETE - Retirer membre
/api/groups/:id/messages    GET    - Messages du groupe
/api/groups/:id/messages    POST   - Envoyer dans groupe

/api/transcription          POST   - Transcrire audio

/api/stats                  GET    - Statistiques utilisateur

/api/settings/notifications PUT    - Paramètres notifs

/api/subscription/status    GET    - Statut abonnement
```

---

## 📦 Dépendances Ajoutées

```yaml
# Audio
record: ^5.1.0                 # Enregistrement audio

# Contacts
contacts_service: ^0.6.3       # Accès contacts téléphone

# Utils
flutter_emoji: ^2.5.1          # Emojis pour réactions
```

**Dépendances existantes utilisées**:
- `provider` - State management
- `http` - Requêtes API
- `web_socket_channel` - Temps réel
- `shared_preferences` - Stockage local
- `permission_handler` - Permissions
- `audioplayers` - Lecture audio
- `path_provider` - Paths système

---

## 🎯 Prochaines Étapes (Phase 2)

### Pages à Créer

1. **Authentification** (`lib/screens/auth/`)
   - [ ] `login_screen.dart`
   - [ ] `register_screen.dart`
   - [ ] `profile_screen.dart`

2. **Paramètres** (`lib/screens/settings/`)
   - [ ] `settings_screen.dart` (refactored)
   - [ ] `notifications_settings_screen.dart`
   - [ ] `theme_settings_screen.dart`
   - [ ] `statistics_screen.dart`
   - [ ] `subscription_screen.dart` (refactored)

3. **Messagerie** (`lib/screens/messaging/`)
   - [ ] `conversation_screen.dart` (refactored)
   - [ ] Widget `message_input_bar.dart` (avec micro)
   - [ ] Widget `message_bubble.dart` (avec long press menu)
   - [ ] Widget `voice_message_player.dart`

4. **Contacts** (`lib/screens/contacts/`)
   - [ ] `contacts_screen.dart` (refactored)
   - [ ] Widget `contact_list_item.dart`

5. **Groupes** (`lib/screens/groups/`)
   - [ ] `groups_screen.dart` (refactored)
   - [ ] `create_group_screen.dart`
   - [ ] `group_conversation_screen.dart`

### Widgets Réutilisables (`lib/widgets/`)

- [ ] `app_button.dart`
- [ ] `app_text_field.dart`
- [ ] `loading_indicator.dart`
- [ ] `error_message.dart`
- [ ] `avatar_widget.dart`
- [ ] `emoji_picker.dart`

### Main App

- [ ] Refactorer `main.dart` avec :
  - MultiProvider (AuthProvider, ThemeProvider, etc.)
  - MaterialApp avec thème dynamique
  - Navigation routes
  - Splash screen / Auth check

---

## 🔐 Authentification Flow

```
1. App démarre
   ↓
2. AuthProvider vérifie token
   ↓
3. Si token valide → Dashboard
   ↓
4. Si pas de token → LoginScreen
   ↓
5. Login/Register → Token sauvegardé
   ↓
6. Navigation vers Dashboard
```

**Protection des routes**:
- Dashboard, Contacts, Messages → Nécessitent authentification
- Si non connecté → Redirection vers Login

---

## 📱 Contacts Flow

```
1. App démarre
   ↓
2. ContactsService.getPhoneContacts()
   ↓
3. Demande permission contacts
   ↓
4. Si accordée → Lecture contacts
   ↓
5. Si connecté → syncContacts() avec backend
   ↓
6. Backend retourne contacts + isRegistered
   ↓
7. Affichage liste avec badge "Sur OmniSMS"
```

---

## 💬 Messagerie Flow

### Envoi Message Texte
```
1. Utilisateur tape message
   ↓
2. Appui sur bouton envoi
   ↓
3. MessagingService.sendTextMessage()
   ↓
4. Backend traite et retourne MessageModel
   ↓
5. Ajout à la liste locale
   ↓
6. WebSocket notifie destinataire
```

### Envoi Message Vocal
```
1. Appui long sur bouton micro
   ↓
2. AudioRecordingService.startRecording()
   ↓
3. Affichage timer + waveform
   ↓
4. Release bouton
   ↓
5. AudioRecordingService.stopRecording()
   ↓
6. MessagingService.sendVoiceMessage(file)
   ↓
7. Backend upload et retourne URL
   ↓
8. Affichage message vocal avec durée
```

### Menu Long Press
```
1. Long press sur message
   ↓
2. Affichage bottom sheet:
   - 😀 Réagir avec emoji
   - 📝 Transcrire (si vocal)
   - 🗑️ Supprimer
   ↓
3. Action choisie → Appel API
```

---

## 🎨 Thème

### Couleur Principale
- **Indigo**: `#6366F1`
- **Material 3**: Activé

### Modes
- **Light**: Fond blanc, texte noir
- **Dark**: Fond noir, texte blanc
- **System**: Auto selon OS

### Changement
```dart
// Dans n'importe quel widget
final themeProvider = context.watch<ThemeProvider>();

// Toggle
themeProvider.toggleTheme();

// Set specific
themeProvider.setThemeMode(ThemeMode.dark);
```

---

## 🔔 Notifications

### Paramètres
- **Notifications** ON/OFF
- **Sons** ON/OFF
- **Alertes** ON/OFF

**Stockage**:
- Local: SharedPreferences
- Backend: Sync automatique si connecté

### Firebase Cloud Messaging
- Déjà configuré dans `firebase_messaging: ^15.1.3`
- Token envoyé au backend lors du login
- Backend envoie push via FCM

---

## 📊 Statistiques

**Affichage**:
- Messages envoyés (total)
- Messages reçus (total)
- Contacts totaux
- Groupes actifs
- Graphiques d'activité (si backend supporte)

**Source**: Backend API `/api/stats`

---

## 🎵 Audio Player

**Pour lecture messages vocaux**:
```dart
import 'package:audioplayers/audioplayers.dart';

final player = AudioPlayer();
await player.play(UrlSource(messageModel.mediaUrl!));
```

**UI**:
- Bouton play/pause
- Barre de progression
- Durée actuelle / totale
- Waveform (optionnel)

---

## 🧪 Tests

### Backend Connection Test
```dart
// Vérifier que le backend répond
final response = await http.get('${ApiConfig.baseUrl}/health');
print(response.statusCode); // Doit être 200
```

### Permissions Test
```dart
// Microphone
final mic = await Permission.microphone.request();
print(mic.isGranted);

// Contacts
final contacts = await Permission.contacts.request();
print(contacts.isGranted);
```

---

## 🚀 Build & Deploy

### Test en développement
```bash
flutter clean
flutter pub get
flutter run
```

### Build APK
```bash
flutter build apk --release --split-per-abi
```

### Build AAB (Play Store)
```bash
flutter build appbundle --release
```

---

## 📝 Notes Importantes

### ✅ Ce qui fonctionne
- Architecture models/services/providers complète
- Authentification avec token
- Contacts du téléphone avec permissions
- Envoi messages texte
- Envoi messages vocaux (avec fichier)
- WebSocket temps réel
- Transcription
- Groupes CRUD
- Paramètres locaux et backend
- Thème clair/sombre

### ⚠️ À compléter
- Pages UI (login, register, profil, settings, etc.)
- Widgets réutilisables
- Navigation routing
- Tests unitaires
- Tests d'intégration
- Documentation utilisateur

### 🔒 Sécurité
- Token JWT stocké en SharedPreferences
- Toutes les routes sensibles nécessitent Authorization header
- Permissions demandées explicitement
- Validation côté backend

---

## 🆘 Troubleshooting

### Problème: "Permission denied" (contacts)
**Solution**: Vérifier `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.READ_CONTACTS" />
```

### Problème: "Permission denied" (microphone)
**Solution**: Vérifier `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### Problème: Backend inaccessible
**Solution**:
1. Vérifier que `http://51.15.89.72:5000` est accessible
2. Tester avec curl: `curl http://51.15.89.72:5000/health`
3. Vérifier firewall/réseau

### Problème: WebSocket se déconnecte
**Solution**:
- Reconnecter automatiquement
- Ajouter heartbeat/ping-pong
- Vérifier logs backend

---

## 📞 Contact & Support

**Repository**: https://github.com/emstronglezin-cmd/Omnisms-frontend  
**Branche**: `feature/complete-backend-integration`  
**Backend**: `http://51.15.89.72:5000`

---

**Date**: 2026-03-06  
**Version**: 2.2.0-alpha  
**Status**: 🚧 En développement (Phase 1 complétée)
