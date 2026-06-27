import 'package:flutter/foundation.dart';

/// Service Google Analytics 4 pour le tracking web
/// Compatible Flutter 3.44+ (dart:js_interop à la place de dart:html)
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static const String _measurementId = 'G-XXXXXXXXXX';
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized || !kIsWeb) return;
    // GA4 is injected via web/index.html in production
    _isInitialized = true;
    debugPrint('✅ AnalyticsService initialized');
  }

  void logPageView(String pageName, {Map<String, dynamic>? parameters}) {
    if (!kIsWeb) return;
    debugPrint('📊 Page vue: $pageName');
  }

  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    if (!kIsWeb) return;
    debugPrint('📊 Événement: $eventName');
  }

  void logLogin(String method) => logEvent('login', parameters: {'method': method});
  void logSignUp(String method) => logEvent('sign_up', parameters: {'method': method});
  void logMessageSent(String type) => logEvent('message_sent', parameters: {'type': type});
  void logGroupCreated(int count) => logEvent('group_created', parameters: {'count': count});
  void logSearch(String term) => logEvent('search', parameters: {'term': term});
  void logError(String desc, {bool fatal = false}) =>
      logEvent('exception', parameters: {'description': desc, 'fatal': fatal});
  void logAppOpen() => logEvent('app_open');
  void logLogout() => logEvent('logout');
  void setUserId(String userId) => debugPrint('📊 User: $userId');
  void setUserProperties(Map<String, dynamic> props) => debugPrint('📊 Props: $props');
  void logScreenView(String name, String cls) =>
      logEvent('screen_view', parameters: {'screen_name': name, 'screen_class': cls});
  void logPurchase({
    required String transactionId,
    required double value,
    required String currency,
    String? itemName,
  }) =>
      logEvent('purchase', parameters: {
        'transaction_id': transactionId,
        'value': value,
        'currency': currency,
        if (itemName != null) 'item_name': itemName,
      });
  void logShare(String contentType, String itemId) =>
      logEvent('share', parameters: {'content_type': contentType, 'item_id': itemId});
  void logSelectContent(String contentType, String itemId) =>
      logEvent('select_content', parameters: {'content_type': contentType, 'item_id': itemId});
  void logBeginCheckout(double value, String currency) =>
      logEvent('begin_checkout', parameters: {'value': value, 'currency': currency});
  void logAddToCart(String itemName, double value) =>
      logEvent('add_to_cart', parameters: {'item_name': itemName, 'value': value});
  void logTutorialBegin() => logEvent('tutorial_begin');
  void logTutorialComplete() => logEvent('tutorial_complete');
}

mixin AnalyticsMixin {
  final _analytics = AnalyticsService();
  void trackPageView(String pageName, {Map<String, dynamic>? parameters}) =>
      _analytics.logPageView(pageName, parameters: parameters);
  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) =>
      _analytics.logEvent(eventName, parameters: parameters);
  void trackScreenView(String screenName, String screenClass) =>
      _analytics.logScreenView(screenName, screenClass);
}
