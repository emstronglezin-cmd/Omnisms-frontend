/// Comment le frontend décide qu'une vérification OTP est exigée.
///
/// Le backend reste la SEULE source de vérité sur l'état de vérification
/// d'un compte : aucun de ces modes ne permet à l'application de déclarer
/// un numéro vérifié d'elle-même.
enum OtpPolicy {
  /// Suit la réponse du serveur : vérification exigée si et seulement si le
  /// backend le demande (`requiresOtp: true` ou `phoneVerified: false`).
  ///
  /// Mode par défaut : il n'impose jamais l'OTP à un compte que le serveur
  /// considère déjà vérifié, et ne bloque donc pas l'inscription si le
  /// backend n'a pas encore été mis à jour.
  followServer,

  /// Exige la vérification après chaque création de compte (inscription
  /// classique ou premier compte Google), même si le serveur a renvoyé un
  /// jeton. Le jeton renvoyé est alors traité comme un jeton D'ATTENTE :
  /// il n'ouvre aucune session et n'est jamais stocké comme jeton d'accès.
  ///
  /// ⚠️ À n'activer qu'APRÈS montage de `routes/otp.js` côté serveur,
  /// sinon l'inscription devient impossible (l'envoi de code échoue).
  alwaysAfterSignup,

  /// N'exige jamais la vérification (secours / incident serveur).
  disabled,
}

/// ApiConfig — Configuration centralisée du backend OmniSMS
///
/// Backend : https://omnisms-backend.onrender.com (Render free tier)
/// Render free tier : spin-down après inactivité → wakeup jusqu'à 50s
class ApiConfig {
  // ── URLs du backend ───────────────────────────────────────────
  static const String baseUrl = 'https://omnisms-backend.onrender.com';
  // Socket.IO uses https:// (not wss://) — the library handles the upgrade
  static const String wsUrl = 'https://omnisms-backend.onrender.com';

  // ── Endpoints API ─────────────────────────────────────────────
  static const String contactsEndpoint = '/api/contacts';
  static const String messagesEndpoint = '/api/messages';
  // Conversations list: GET /api/messages
  static const String conversationsEndpoint = '/api/messages';
  // Send message: POST /api/messages/send
  static const String sendMessageEndpoint = '/api/messages/send';
  // Groups: route mounted at /groups (NOT /api/groups)
  static const String groupsEndpoint = '/groups';
  static const String transcriptionEndpoint = '/api/transcription';

  // Paiement LeekPay (routes correctes)
  static const String paymentLeekpayEndpoint = '/api/payment/leekpay';

  static const String paymentStatusEndpoint = '/api/payment/user-status';

  static const String subscriptionEndpoint = '/api/user/status';
  // Auth
  static const String authRegisterEndpoint = '/api/auth/register';
  static const String authLoginEndpoint = '/api/auth/login';
  static const String authMeEndpoint = '/api/auth/me';

  // ── Vérification du numéro de téléphone par OTP ────────────────
  //
  // Contrat RÉEL, relevé dans le backend (`routes/otp.js` +
  // `services/otpService.js`) — aucun champ inventé ici :
  //
  //   POST /api/auth/send-otp    body { phone, userId? }
  //      200 → { success: true,  message, phone, devCode? }
  //      429 → { success: false, code: 'OTP_COOLDOWN', cooldown (secondes) }
  //      400 → { success: false, code: 'VALIDATION_ERROR' | 'OTP_SEND_FAILED' }
  //
  //   POST /api/auth/verify-otp  body { phone, code, userId? }
  //      200 → { success: true, token, phoneVerified: true, user }
  //      400 → { code: 'OTP_INVALID',    triesRemaining }
  //      410 → { code: 'OTP_EXPIRED' }
  //      429 → { code: 'OTP_MAX_TRIES' }
  //      404 → { code: 'OTP_NOT_FOUND' }
  //
  // ⚠️ ÉTAT RÉEL DU BACKEND (vérifié le 21/10/2026) : `routes/otp.js`
  // n'est monté NULLE PART (`server.js` : « OTP routes supprimées —
  // inscription directe sans OTP ») et `POST /api/auth/register` crée
  // l'utilisateur avec `phoneVerified: true` en dur.
  // Tant que le backend n'a pas évolué, ces deux endpoints répondent donc
  // 404 : le frontend ÉCHOUE FERMÉ (message « service indisponible ») et ne
  // valide jamais un numéro de sa propre initiative.
  static const String authSendOtpEndpoint = '/api/auth/send-otp';
  static const String authVerifyOtpEndpoint = '/api/auth/verify-otp';

  /// Longueur du code : le backend génère 6 chiffres
  /// (`services/otpService.js`, `OTP_LENGTH = 6`) et accepte 4 à 8.
  static const int otpCodeLength = 6;

  /// Délai minimum entre deux envois (`OTP_COOLDOWN_MS` = 60 s).
  static const int otpResendCooldownSeconds = 60;

  /// Durée de validité d'un code (`OTP_TTL_MS` = 10 minutes).
  static const int otpValiditySeconds = 600;

  /// Politique d'exigence de la vérification OTP côté client.
  ///
  /// Voir [OtpPolicy] pour le détail. La valeur par défaut suit le serveur :
  /// c'est le backend qui reste seul juge de l'état de vérification d'un
  /// compte — jamais l'écran affiché par l'application.
  static const OtpPolicy otpPolicy = OtpPolicy.followServer;

  // ── Profil (mêmes routes que la PWA — public/app.js) ────────
  // GET    /api/me           → profil courant
  // PUT    /api/me/profile   → mise à jour (name, username, phone, email, password)
  // POST   /api/me/avatar    → upload photo (multipart, champ « avatar »)
  // DELETE /api/me           → suppression du compte
  static const String meEndpoint = '/api/me';
  static const String meProfileEndpoint = '/api/me/profile';
  static const String meAvatarEndpoint = '/api/me/avatar';

  // ── Audio (messages vocaux + transcription) ─────────────────
  // POST /api/audio/upload            → { id, url, duration, durationFormatted }
  // POST /api/audio/transcribe/:msgId → lance la transcription
  // GET  /api/audio/:msgId            → { transcriptionStatus, transcription }
  static const String audioUploadEndpoint = '/api/audio/upload';
  static String audioTranscribeEndpoint(String messageId) =>
      '/api/audio/transcribe/$messageId';
  static String audioMessageEndpoint(String messageId) =>
      '/api/audio/$messageId';

  // ── Contacts ────────────────────────────────────────────────
  static const String contactsSyncEndpoint = '/api/contacts/sync';
  static const String contactsAddEndpoint = '/api/contacts/add';
  static String contactByPhoneEndpoint(String phone) =>
      '/api/contacts/${Uri.encodeComponent(phone)}';
  static String contactCheckEndpoint(String phone) =>
      '/api/contacts/check/${Uri.encodeComponent(phone)}';

  // ── Paiement (fallback polling quand le webhook tarde) ───────
  static String paymentPollEndpoint(String checkoutId) =>
      '/api/payment/poll/${Uri.encodeComponent(checkoutId)}';

  // ── Google Auth (contrat backend : docs/GOOGLE_AUTH_FLUTTER.md) ──
  // 1. GET  /api/auth/google                  → ouverture dans le navigateur système
  //    (redirige vers Google, puis vers le deep link Flutter avec un code à usage unique)
  static const String authGoogleStartEndpoint = '/api/auth/google';
  // 2. POST /api/auth/google/exchange         → { code } → { token, user }
  static const String authGoogleExchangeEndpoint = '/api/auth/google/exchange';
  // 3. POST /api/auth/google/contacts/authorize (Bearer requis)
  //    → { authorizationUrl, redirectUri, scope }
  static const String googleContactsAuthorizeEndpoint =
      '/api/auth/google/contacts/authorize';
  // 4. POST /api/contacts/google/import (Bearer requis) → compteurs d'import
  static const String googleContactsImportEndpoint =
      '/api/contacts/google/import';

  // ── Deep links Flutter (définis par le backend) ───────────────
  // Schéma enregistré dans AndroidManifest.xml / Info.plist.
  static const String googleDeepLinkScheme = 'omnisms';
  static const String googleLoginCallbackPath = '/auth/google/callback';
  static const String googleContactsCallbackPath =
      '/auth/google/contacts/callback';

  // ── Hôtes HTTPS autorisés à porter un retour OAuth ───────────
  //
  // Le backend choisit la cible du retour après consentement Google :
  //   • variante « app » (défaut, sans `?target=web`)
  //       → GOOGLE_FLUTTER_REDIRECT_URI
  //   • variante « web » (`?target=web`)
  //       → GOOGLE_FLUTTER_REDIRECT_URI_WEB
  //
  // En production, GOOGLE_FLUTTER_REDIRECT_URI pointe aujourd'hui vers la
  // PWA Vercel (`https://omnisms-frontend-drab.vercel.app/`) : le retour
  // atterrit donc dans le navigateur, pas dans l'APK. L'APK revendique ces
  // hôtes via Android App Links (AndroidManifest, autoVerify) pour récupérer
  // le code au lieu d'ouvrir la PWA.
  //
  // Ces hôtes servent UNIQUEMENT à reconnaître un callback, et seulement
  // pendant un flux Google ouvert par l'application : aucun autre lien
  // (même porteur d'un paramètre `code`) n'est détourné.
  static const List<String> googleCallbackHosts = <String>[
    'omnisms-frontend-drab.vercel.app',
    'omnisms.vercel.app',
    'omnisms.onrender.com',
  ];

  /// `true` si [host] est autorisé à porter un retour OAuth Google.
  static bool isGoogleCallbackHost(String? host) {
    if (host == null || host.isEmpty) return false;
    final normalized = host.toLowerCase().split(':').first;
    return googleCallbackHosts
        .any((allowed) => allowed.toLowerCase() == normalized);
  }

  // ── Headers par défaut ────────────────────────────────────────
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Map<String, String> get defaultHeaders => headers;

  // ── Groupes (routes montées à /groups, pas /api/groups) ──────
  static String groupMembersEndpoint(String groupId) => '/groups/$groupId/members';
  static String groupMessagesEndpoint(String groupId) => '/groups/$groupId/messages';
  static String groupAdminEndpoint(String groupId) => '/groups/$groupId/admin';
  static String groupAvatarEndpoint(String groupId) => '/groups/$groupId/avatar';

  // ── Résolution d'URL média ────────────────────────────────────
  /// Le backend renvoie parfois des chemins relatifs (/uploads/audio/…).
  /// Dans ce cas on les préfixe avec l'URL du backend, exactement comme
  /// le fait la PWA (public/app.js — renderAudioMessage / uploadVoiceMessage).
  static String resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('data:') ||
        url.startsWith('http://') ||
        url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/') && !url.startsWith('//')) {
      return '$baseUrl$url';
    }
    return url;
  }

  // ── Timeouts ──────────────────────────────────────────────────
  // Render free tier peut prendre jusqu'à 50s pour se réveiller
  static const Duration requestTimeout = Duration(seconds: 60);
  static const Duration connectionTimeout = Duration(seconds: 60);
  // Premier appel après inactivité (wakeup)
  static const Duration wakeupTimeout = Duration(seconds: 70);
}
