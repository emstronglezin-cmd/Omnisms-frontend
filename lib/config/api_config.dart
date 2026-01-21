class ApiConfig {
  // Configuration de base pour votre backend
  static const String baseUrl = 'http://51.15.89.72'; // Updated Backend URL
  static const String wsUrl = 'ws://51.15.89.72/ws'; // Updated WebSocket URL

  // Endpoints API
  static const String contactsEndpoint = '/api/contacts';
  static const String messagesEndpoint = '/api/messages';
  static const String sendMessageEndpoint = '/api/messages/send';

  // Headers par défaut
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Timeout pour les requêtes HTTP
  static const Duration requestTimeout = Duration(seconds: 30);

  // Keys for external services
  static const String stripePublicKey = 'YOUR_STRIPE_PUBLIC_KEY';
  static const String flutterwavePublicKey = 'YOUR_FLUTTERWAVE_PUBLIC_KEY';
  static const String twilioSid = 'YOUR_TWILIO_SID';
  static const String twilioAuthToken = 'YOUR_TWILIO_AUTH_TOKEN';
  static const String twilioPhoneNumber = 'YOUR_TWILIO_PHONE_NUMBER';
}
