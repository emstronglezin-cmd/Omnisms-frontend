import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Service de notifications web — stub sans Firebase
/// Firebase Messaging sera réintégré après ajout de Firebase.initializeApp() dans main.dart
class WebNotificationService {
  static final WebNotificationService _instance = WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();

  bool _isInitialized = false;
  String? _fcmToken;

  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;

  String? get fcmToken => _fcmToken;

  /// Initialiser les notifications push (stub)
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      if (kIsWeb) {
        debugPrint('ℹ️ WebNotificationService: Firebase non configuré, notifications désactivées');
      }
      _isInitialized = true;
      return false; // pas de vraies notifs sans Firebase
    } catch (e) {
      debugPrint('⚠️ WebNotificationService init: $e');
      return false;
    }
  }

  /// Vérifier si les notifications sont activées
  Future<bool> areNotificationsEnabled() async => false;

  /// Envoyer une notification de test (no-op)
  Future<void> sendTestNotification() async {
    debugPrint('ℹ️ sendTestNotification: Firebase non configuré');
  }

  /// S'abonner à un topic (no-op)
  Future<void> subscribeToTopic(String topic) async {}

  /// Se désabonner d'un topic (no-op)
  Future<void> unsubscribeFromTopic(String topic) async {}

  /// Nettoyer les ressources
  void dispose() {
    _notificationController.close();
  }
}

/// Widget pour afficher une notification in-app
class InAppNotification extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const InAppNotification({
    super.key,
    required this.title,
    required this.body,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0f1520),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00d4ff).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00d4ff).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Color(0xFF00d4ff),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFe8edf5),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Color(0xFF6b7a96),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF6b7a96)),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
