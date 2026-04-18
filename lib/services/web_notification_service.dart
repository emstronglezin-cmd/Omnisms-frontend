import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Service de gestion des notifications push web (FCM)
class WebNotificationService {
  static final WebNotificationService _instance = WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _isInitialized = false;

  // Stream controller pour les notifications
  final _notificationController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onNotification => _notificationController.stream;

  /// Initialiser les notifications push
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Demander la permission (web)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notifications autorisées');
        
        // Obtenir le token FCM
        if (kIsWeb) {
          _fcmToken = await _messaging.getToken(
            vapidKey: 'BKxg9xZ9xZ9xZ9xZ9xZ9xZ9xZ9xZ9xZ9xZ9xZ9xZ9xZ9xZ9xZ', // Remplacer par votre VAPID key
          );
        } else {
          _fcmToken = await _messaging.getToken();
        }
        
        if (_fcmToken != null) {
          debugPrint('🔑 FCM Token: $_fcmToken');
          await _saveFcmToken(_fcmToken!);
          
          // Envoyer le token au backend
          await _sendTokenToBackend(_fcmToken!);
        }

        // Écouter les messages en foreground
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Écouter les clics sur notifications
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);

        // Vérifier si l'app a été ouverte par une notification
        RemoteMessage? initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationClick(initialMessage);
        }

        // Écouter les changements de token
        _messaging.onTokenRefresh.listen((newToken) async {
          _fcmToken = newToken;
          await _saveFcmToken(newToken);
          await _sendTokenToBackend(newToken);
          debugPrint('🔄 FCM Token refreshed: $newToken');
        });

        _isInitialized = true;
        return true;
      } else {
        debugPrint('❌ Notifications refusées');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur initialisation notifications: $e');
      return false;
    }
  }

  /// Gérer les messages en foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Nouveau message: ${message.notification?.title}');
    
    // Ajouter au stream
    _notificationController.add(message);
    
    // Afficher une notification locale si besoin
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'OmniSMS',
        body: message.notification!.body ?? '',
        data: message.data,
      );
    }
  }

  /// Gérer les clics sur notifications
  void _handleNotificationClick(RemoteMessage message) {
    debugPrint('👆 Notification clicked: ${message.data}');
    
    // Router vers la bonne page selon le type
    final type = message.data['type'] ?? '';
    final id = message.data['id'] ?? '';
    
    // TODO: Implémenter la navigation selon le type
    // Exemples:
    // - type: 'message' -> ouvrir conversation
    // - type: 'group' -> ouvrir groupe
    // - type: 'contact' -> ouvrir contact
  }

  /// Afficher une notification locale
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Sur web, utiliser l'API Notifications du navigateur
    if (kIsWeb) {
      // Les notifications sont gérées automatiquement par le service worker
      debugPrint('🔔 Notification: $title - $body');
    }
  }

  /// Sauvegarder le token FCM localement
  Future<void> _saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// Récupérer le token FCM sauvegardé
  Future<String?> getSavedFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  /// Envoyer le token au backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      // TODO: Appeler votre API pour enregistrer le token
      // Exemple:
      // await http.post(
      //   Uri.parse('${ApiConfig.baseUrl}/api/users/fcm-token'),
      //   headers: {'Authorization': 'Bearer $authToken'},
      //   body: json.encode({'fcm_token': token, 'platform': 'web'}),
      // );
      debugPrint('📤 Token envoyé au backend');
    } catch (e) {
      debugPrint('❌ Erreur envoi token: $e');
    }
  }

  /// Envoyer une notification de test
  Future<void> sendTestNotification() async {
    if (_fcmToken == null) {
      debugPrint('❌ Pas de token FCM');
      return;
    }

    try {
      // TODO: Appeler votre API pour envoyer une notification de test
      debugPrint('📤 Envoi notification de test...');
    } catch (e) {
      debugPrint('❌ Erreur envoi test: $e');
    }
  }

  /// S'abonner à un topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ Abonné au topic: $topic');
    } catch (e) {
      debugPrint('❌ Erreur abonnement topic: $e');
    }
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Désabonné du topic: $topic');
    } catch (e) {
      debugPrint('❌ Erreur désabonnement topic: $e');
    }
  }

  /// Obtenir le token FCM actuel
  String? get fcmToken => _fcmToken;

  /// Vérifier si les notifications sont activées
  Future<bool> areNotificationsEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

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
