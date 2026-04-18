import 'package:flutter/foundation.dart';
import 'dart:html' as html;

/// Service Google Analytics 4 pour le tracking web
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // Votre ID de mesure GA4
  static const String _measurementId = 'G-XXXXXXXXXX'; // À remplacer
  bool _isInitialized = false;

  /// Initialiser Google Analytics
  Future<void> initialize() async {
    if (_isInitialized || !kIsWeb) return;

    try {
      // Injecter le script GA4
      final script1 = html.ScriptElement()
        ..async = true
        ..src = 'https://www.googletagmanager.com/gtag/js?id=$_measurementId';
      html.document.head?.append(script1);

      // Injecter le code d'initialisation
      final script2 = html.ScriptElement()
        ..text = '''
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', '$_measurementId', {
            'send_page_view': false,
            'anonymize_ip': true
          });
        ''';
      html.document.head?.append(script2);

      _isInitialized = true;
      debugPrint('✅ Google Analytics initialisé');
    } catch (e) {
      debugPrint('❌ Erreur initialisation GA: $e');
    }
  }

  /// Logger une page vue
  void logPageView(String pageName, {Map<String, dynamic>? parameters}) {
    if (!_isInitialized || !kIsWeb) return;

    try {
      _gtag('event', 'page_view', {
        'page_title': pageName,
        'page_location': html.window.location.href,
        'page_path': html.window.location.pathname,
        ...?parameters,
      });
      debugPrint('📊 Page vue: $pageName');
    } catch (e) {
      debugPrint('❌ Erreur log page: $e');
    }
  }

  /// Logger un événement personnalisé
  void logEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) {
    if (!_isInitialized || !kIsWeb) return;

    try {
      _gtag('event', eventName, parameters ?? {});
      debugPrint('📊 Événement: $eventName');
    } catch (e) {
      debugPrint('❌ Erreur log event: $e');
    }
  }

  /// Logger une connexion
  void logLogin(String method) {
    logEvent('login', parameters: {'method': method});
  }

  /// Logger une inscription
  void logSignUp(String method) {
    logEvent('sign_up', parameters: {'method': method});
  }

  /// Logger un achat/abonnement
  void logPurchase({
    required String transactionId,
    required double value,
    required String currency,
    String? itemName,
  }) {
    logEvent('purchase', parameters: {
      'transaction_id': transactionId,
      'value': value,
      'currency': currency,
      if (itemName != null) 'item_name': itemName,
    });
  }

  /// Logger l'envoi d'un message
  void logMessageSent(String type) {
    logEvent('message_sent', parameters: {'message_type': type});
  }

  /// Logger la création d'un groupe
  void logGroupCreated(int memberCount) {
    logEvent('group_created', parameters: {'member_count': memberCount});
  }

  /// Logger une recherche
  void logSearch(String searchTerm) {
    logEvent('search', parameters: {'search_term': searchTerm});
  }

  /// Logger un partage
  void logShare(String contentType, String itemId) {
    logEvent('share', parameters: {
      'content_type': contentType,
      'item_id': itemId,
    });
  }

  /// Logger une erreur
  void logError(String description, {bool fatal = false}) {
    logEvent('exception', parameters: {
      'description': description,
      'fatal': fatal,
    });
  }

  /// Définir les propriétés utilisateur
  void setUserProperties(Map<String, dynamic> properties) {
    if (!_isInitialized || !kIsWeb) return;

    try {
      _gtag('set', 'user_properties', properties);
      debugPrint('📊 Propriétés utilisateur définies');
    } catch (e) {
      debugPrint('❌ Erreur set properties: $e');
    }
  }

  /// Définir l'ID utilisateur
  void setUserId(String userId) {
    if (!_isInitialized || !kIsWeb) return;

    try {
      _gtag('set', {'user_id': userId});
      debugPrint('📊 User ID défini: $userId');
    } catch (e) {
      debugPrint('❌ Erreur set user ID: $e');
    }
  }

  /// Logger une session de début
  void logAppOpen() {
    logEvent('app_open');
  }

  /// Logger une déconnexion
  void logLogout() {
    logEvent('logout');
  }

  /// Logger une action sur un tutoriel
  void logTutorialBegin() {
    logEvent('tutorial_begin');
  }

  void logTutorialComplete() {
    logEvent('tutorial_complete');
  }

  /// Logger un ajout au panier
  void logAddToCart(String itemName, double value) {
    logEvent('add_to_cart', parameters: {
      'item_name': itemName,
      'value': value,
    });
  }

  /// Logger le début d'un checkout
  void logBeginCheckout(double value, String currency) {
    logEvent('begin_checkout', parameters: {
      'value': value,
      'currency': currency,
    });
  }

  /// Logger la sélection d'un contenu
  void logSelectContent(String contentType, String itemId) {
    logEvent('select_content', parameters: {
      'content_type': contentType,
      'item_id': itemId,
    });
  }

  /// Logger le temps passé sur un écran
  void logScreenView(String screenName, String screenClass) {
    logEvent('screen_view', parameters: {
      'screen_name': screenName,
      'screen_class': screenClass,
    });
  }

  /// Appeler gtag
  void _gtag(String command, dynamic arg1, [dynamic arg2]) {
    if (!kIsWeb) return;
    
    try {
      html.window.callMethod('gtag', [command, arg1, if (arg2 != null) arg2]);
    } catch (e) {
      debugPrint('❌ Erreur gtag call: $e');
    }
  }
}

/// Mixin pour faciliter l'utilisation d'Analytics dans les widgets
mixin AnalyticsMixin {
  final _analytics = AnalyticsService();

  void trackPageView(String pageName, {Map<String, dynamic>? parameters}) {
    _analytics.logPageView(pageName, parameters: parameters);
  }

  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    _analytics.logEvent(eventName, parameters: parameters);
  }

  void trackScreenView(String screenName, String screenClass) {
    _analytics.logScreenView(screenName, screenClass);
  }
}
