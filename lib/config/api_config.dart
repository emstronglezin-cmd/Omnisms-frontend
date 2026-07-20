class ApiConfig {
  // ── Backend URL ───────────────────────────────────────────────
  static const String baseUrl = 'https://omnisms-backend.onrender.com';
  static const String wsUrl = 'wss://omnisms-backend.onrender.com';

  // ── API Endpoints ─────────────────────────────────────────────
  static const String contactsEndpoint      = '/api/contacts';
  static const String messagesEndpoint      = '/api/messages';
  static const String sendMessageEndpoint   = '/api/messages/send';
  static const String groupsEndpoint        = '/api/groups';
  static const String subscriptionEndpoint  = '/api/subscription/status';
  static const String paymentsEndpoint      = '/api/payments/create';
  static const String transcriptionEndpoint = '/api/transcription';

  // ── Request Headers ───────────────────────────────────────────
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Timeouts ─────────────────────────────────────────────────
  // Render free tier peut prendre jusqu'à 50s pour se réveiller
  static const Duration requestTimeout    = Duration(seconds: 60);
  static const Duration connectionTimeout = Duration(seconds: 60);
  // Timeout spécial pour le premier appel (wakeup)
  static const Duration wakeupTimeout     = Duration(seconds: 70);

  // ── Backward compat ───────────────────────────────────────────
  static Map<String, String> get defaultHeaders => headers;
}
