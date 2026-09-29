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

  // ── Headers par défaut ────────────────────────────────────────
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Map<String, String> get defaultHeaders => headers;

  // ── Timeouts ──────────────────────────────────────────────────
  // Render free tier peut prendre jusqu'à 50s pour se réveiller
  static const Duration requestTimeout = Duration(seconds: 60);
  static const Duration connectionTimeout = Duration(seconds: 60);
  // Premier appel après inactivité (wakeup)
  static const Duration wakeupTimeout = Duration(seconds: 70);
}
