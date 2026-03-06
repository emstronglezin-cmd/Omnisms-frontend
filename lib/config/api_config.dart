class ApiConfig {
  // Backend Configuration
  static const String baseUrl = 'http://51.15.89.72:5000';
  static const String wsUrl = 'ws://51.15.89.72:5000/ws';
  
  // API Endpoints
  static const String contactsEndpoint = '/api/contacts';
  static const String messagesEndpoint = '/api/messages';
  static const String sendMessageEndpoint = '/api/messages/send';
  static const String groupsEndpoint = '/api/groups';
  static const String subscriptionEndpoint = '/api/subscription/status';
  static const String paymentsEndpoint = '/api/payments/create';
  static const String transcriptionEndpoint = '/api/transcription';
  
  // Request Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 15);
  
  // Firebase
  static const String firebaseApiKey = 'AIzaSyD3Yur6Q5IvcDI_bC9YuLFNC4jvgEREtBQ';
  static const String firebaseProjectId = 'omnisms-b98c5';
  static const String firebaseStorageBucket = 'omnisms-b98c5.firebasestorage.app';
  
  // Start.io Ad Configuration
  static const String startIoAppId = 'YOUR_STARTIO_APP_ID'; // À remplacer
  
  // Payment Services
  static const String stripePublishableKey = 'YOUR_STRIPE_KEY';
  static const String flutterwavePublicKey = 'YOUR_FLUTTERWAVE_KEY';
}
