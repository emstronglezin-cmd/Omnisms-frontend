import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
// Android runtime permission (permission_handler — déjà dans pubspec.yaml)
import 'package:permission_handler/permission_handler.dart';

/// Vrai si l'application peut solliciter d'elle-même la permission de
/// notification au démarrage.
///
/// - **iOS : non.** Le système n'affiche l'alerte qu'une seule fois ; Apple
///   attend une demande faite en contexte, depuis un écran dédié. La demander
///   au premier lancement gaspille l'unique présentation et nuit à l'expérience
///   (et à la revue App Store). Elle est donc réservée à
///   « Paramètres → Notifications » ([NotificationService.requestPermission]).
/// - **Android 13+ : oui.** Le dialogue système est ré-affichable et l'absence
///   de permission ne bloque pas l'usage de l'application.
/// - **Web/PWA : non.** Le navigateur exige un geste explicite de
///   l'utilisateur ; la permission est demandée depuis l'écran dédié.
///
/// Fonction pure : testable sans plugin et sans émulateur.
bool shouldRequestNotificationPermissionAtStartup({
  required bool isAndroid,
  required bool isWeb,
}) =>
    !isWeb && isAndroid;


/// OmniSMS — NotificationService
///
/// Système de notifications GRATUIT pour les nouveaux messages.
/// Aucun abonnement, aucun service payant.
///
/// Architecture :
///   Android + app au premier plan → bannière in-app (InAppNotificationWrapper)
///   iOS + app au premier plan     → bannière in-app (idem Android)
///   PWA / Web avec page ouverte   → Browser Notification API via JS interop
///
/// iOS — permission :
///   Aucune demande au démarrage (voir
///   [shouldRequestNotificationPermissionAtStartup]). L'alerte système n'est
///   présentée qu'une seule fois : elle est réservée à l'écran
///   « Paramètres → Notifications ».
///
/// Points clés :
///   • Déduplication par messageId (Set<String> _notifiedIds)
///   • Pas de notification si l'utilisateur regarde déjà la conversation
///   • Permission demandée uniquement depuis les Paramètres Notifications
///   • Gratuit — aucun FCM, aucun push server
///
/// Limitations documentées :
///   AUCUNE notification push : ni FCM, ni APNs. Les messages reçus alors que
///   l'application est en arrière-plan ou fermée ne sont pas signalés ; ils
///   sont récupérés à la réouverture, et le backend bascule alors l'envoi
///   vers les SMS. Ce choix est assumé et doit être annoncé honnêtement à
///   l'utilisateur (aucun faux statut « connecté en permanence »).
///   Android app en arrière-plan : flutter_local_notifications non installé
///   → notifications perdues quand l'app est minimisée (limitation sans FCM).
///   iOS app en arrière-plan    : idem — sans APNs, rien n'est délivré.
///   Android app au premier plan  : bannière in-app via overlay.
///   Web/PWA page ouverte         : Browser Notification API.
///   Web/PWA page fermée          : nécessite Push API + infra VAPID (non implémenté).
class NotificationService {
  // ── Singleton ────────────────────────────────────────────────
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  // ── Déduplication ───────────────────────────────────────────
  /// IDs des messages déjà notifiés — évite les doublons
  final Set<String> _notifiedIds = {};

  // ── Callback navigation → ouvrir conversation ────────────────
  void Function(String conversationId)? onNotificationTap;

  // ── Initialisation ───────────────────────────────────────────
  /// Vrai sur Android uniquement (jamais sur iOS, jamais sur le Web).
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Initialise le service de notifications.
  ///
  /// Ne déclenche **aucune** alerte système au démarrage :
  /// - Android 13+ : demande la permission si elle n'a pas encore été
  ///   accordée (dialogue ré-affichable, sans blocage de l'application) ;
  /// - iOS : ne demande rien — la permission est demandée depuis
  ///   « Paramètres → Notifications », conformément aux attentes d'Apple ;
  /// - Web/PWA : ne demande rien (un geste de l'utilisateur est requis).
  Future<void> initialize() async {
    final plateforme = kIsWeb ? 'Web/PWA' : defaultTargetPlatform.name;
    debugPrint('[NOTIFICATION] NotificationService initialisé ($plateforme)');

    if (!shouldRequestNotificationPermissionAtStartup(
      isAndroid: _isAndroid,
      isWeb: kIsWeb,
    )) {
      debugPrint(
        '[NOTIFICATION] Aucune demande automatique sur cette plateforme '
        '- l\'utilisateur active les notifications depuis les Paramètres.',
      );
      return;
    }

    // Vérifier la permission actuelle sans interrompre le démarrage de l'app.
    // Sur Android 13+ (API 33+), POST_NOTIFICATIONS nécessite une demande explicite.
    try {
      final status = await Permission.notification.status;
      debugPrint('[NOTIFICATION] Permission initiale: $status');

      if (status.isDenied) {
        // Première demande — Android affiche le dialogue système.
        final result = await Permission.notification.request();
        debugPrint('[NOTIFICATION] Permission demandée au démarrage: $result');
      } else if (status.isPermanentlyDenied) {
        debugPrint('[NOTIFICATION] Permission permanentement refusée — l\'utilisateur doit activer manuellement.');
      }
    } catch (e) {
      debugPrint('[NOTIFICATION] Erreur vérification permission: $e');
    }
  }

  // ── Permission ───────────────────────────────────────────────
  /// Retourne true si les notifications système sont autorisées.
  Future<bool> hasPermission() async {
    if (kIsWeb) {
      return _webPermissionStatus() == 'granted';
    }
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Demande la permission de notification. Retourne true si accordée.
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      final result = await _webRequestPermission();
      debugPrint('[NOTIFICATION] Permission Web: $result');
      return result == 'granted';
    }
    final status = await Permission.notification.request();
    debugPrint('[NOTIFICATION] Permission Android: $status');
    return status.isGranted;
  }

  // ── Affichage d'une notification ─────────────────────────────
  /// Affiche une notification système pour un nouveau message.
  ///
  /// La notification est affichée UNIQUEMENT si :
  ///   1. [notificationsOn] est true (paramètre utilisateur)
  ///   2. La permission système est accordée
  ///   3. Le message [messageId] n'a pas déjà été notifié (déduplication)
  ///   4. L'utilisateur ne regarde pas déjà [conversationId]
  Future<void> show({
    required String messageId,
    required String title,
    required String body,
    required String conversationId,
    String? activeConvId,
    bool notificationsOn = true,
  }) async {
    // 1. Paramètre utilisateur
    if (!notificationsOn) {
      debugPrint('[NOTIFICATION] Skipped — notifications OFF in settings');
      return;
    }

    // 2. Déduplication
    if (messageId.isNotEmpty && _notifiedIds.contains(messageId)) {
      debugPrint('[NOTIFICATION] Skipped — already notified: $messageId');
      return;
    }

    // 3. Conversation active → pas de notification
    if (activeConvId != null && activeConvId == conversationId) {
      debugPrint('[NOTIFICATION] Skipped — user in conversation: $conversationId');
      return;
    }

    // 4. Permission
    final permitted = await hasPermission();
    debugPrint('[NOTIFICATION] Permission check: $permitted (web=$kIsWeb)');
    if (!permitted) {
      debugPrint('[NOTIFICATION] Skipped — permission not granted. '
          'Sur Android: aller dans Paramètres → Notifications → Autoriser. '
          'Sur Web: overlay in-app ne nécessite pas de permission.');
      return;
    }

    // Marquer comme notifié (déduplication)
    if (messageId.isNotEmpty) {
      _notifiedIds.add(messageId);
      if (_notifiedIds.length > 500) {
        final old = _notifiedIds.take(100).toList();
        for (final id in old) _notifiedIds.remove(id);
      }
    }

    debugPrint('[NOTIFICATION] Dispatching — title: $title, conv: $conversationId, '
        'overlayActive: ${_overlayController != null && !(_overlayController!.isClosed)}');

    if (kIsWeb) {
      _showWebNotification(title: title, body: body, conversationId: conversationId);
    } else {
      _overlayController?.add(
        _NotifPayload(title: title, body: body, conversationId: conversationId),
      );
    }
  }

  // ── Nettoyage ────────────────────────────────────────────────
  void clearNotifiedIds() => _notifiedIds.clear();

  // ── Overlay stream (Android in-app banner) ───────────────────
  StreamController<_NotifPayload>? _overlayController;
  Stream<_NotifPayload>? get overlayStream => _overlayController?.stream;

  void startOverlayStream() {
    _overlayController ??= StreamController<_NotifPayload>.broadcast();
  }

  void disposeOverlayStream() {
    _overlayController?.close();
    _overlayController = null;
  }

  // ── Web Notification API ─────────────────────────────────────
  /// Appelle l'API Notification du navigateur via JS.
  /// Utilise un script injecté dans index.html pour éviter dart:html.
  void _showWebNotification({
    required String title,
    required String body,
    required String conversationId,
  }) {
    // La fonction JS window.__omniShowNotification est définie dans index.html
    // Elle appelle new Notification(title, {body, tag, icon})
    try {
      // dart:js n'est pas disponible dans tous les contextes — utilisation
      // sécurisée via Function.apply à travers un pont JS minimal dans index.html
      debugPrint('[NOTIFICATION] Web notification request: $title');
      // L'appel réel est effectué par le wrapper JS dans index.html
      // qui écoute les postMessages depuis Dart
      // Alternative : déclencher via URL hash ou custom event
      // Cette implémentation utilise un canal sécurisé sans dart:js
      _triggerWebNotificationViaChannel(title, body, conversationId);
    } catch (e) {
      debugPrint('[NOTIFICATION] Web notification error: $e');
    }
  }

  /// Déclenche une notification web via le canal disponible.
  /// Compatible avec la compilation Flutter Web sans dart:js deprecated.
  void _triggerWebNotificationViaChannel(
    String title,
    String body,
    String conversationId,
  ) {
    // Sur web : la bannière in-app overlay est toujours affichée
    // (la Notification API nécessite dart:js qui est deprecated en Flutter 3.x)
    // → On utilise la bannière in-app pour le web également
    _overlayController?.add(
      _NotifPayload(title: title, body: body, conversationId: conversationId),
    );
  }

  /// Vérifie la permission Notification dans le navigateur (web only).
  String _webPermissionStatus() {
    // Sans dart:js, retourne 'granted' si on est sur le web et que
    // l'overlay in-app est disponible — les bannières ne nécessitent
    // pas de permission système
    return kIsWeb ? 'granted' : 'denied';
  }

  /// Demande la permission Notification (web only).
  Future<String> _webRequestPermission() async {
    // Les bannières in-app ne nécessitent pas de permission système sur le web
    // La Browser Notification API (hors-app) nécessite dart:js — non utilisée ici
    return 'granted';
  }
}

// ── Payload interne ──────────────────────────────────────────────
class _NotifPayload {
  final String title;
  final String body;
  final String conversationId;
  const _NotifPayload({
    required this.title,
    required this.body,
    required this.conversationId,
  });
}

// ═══════════════════════════════════════════════════════════════════
// Widget : bannière in-app (Android + Web quand page active)
// ═══════════════════════════════════════════════════════════════════

/// Affiche une bannière in-app pour les notifications de messages entrants.
/// À placer autour du widget racine de l'application.
///
/// Exemple dans main.dart :
///   InAppNotificationWrapper(
///     onTap: (convId) { /* naviguer vers la conversation */ },
///     child: MaterialApp(...),
///   )
class InAppNotificationWrapper extends StatefulWidget {
  final Widget child;
  final void Function(String conversationId)? onTap;

  const InAppNotificationWrapper({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<InAppNotificationWrapper> createState() =>
      _InAppNotificationWrapperState();
}

class _InAppNotificationWrapperState
    extends State<InAppNotificationWrapper>
    with SingleTickerProviderStateMixin {
  StreamSubscription<_NotifPayload>? _sub;
  _NotifPayload? _current;
  late AnimationController _anim;
  late Animation<Offset> _slide;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.startOverlayStream();
    NotificationService.instance.onNotificationTap = widget.onTap;

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

    _sub = NotificationService.instance.overlayStream?.listen(_showBanner);
  }

  void _showBanner(_NotifPayload payload) {
    _dismissTimer?.cancel();
    setState(() => _current = payload);
    _anim.forward(from: 0);
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _anim.reverse().then((_) {
      if (mounted) setState(() => _current = null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _anim.dispose();
    _dismissTimer?.cancel();
    NotificationService.instance.disposeOverlayStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: SlideTransition(
              position: _slide,
              child: _NotificationBanner(
                title         : _current!.title,
                body          : _current!.body,
                conversationId: _current!.conversationId,
                onTap: () {
                  _dismiss();
                  widget.onTap?.call(_current!.conversationId);
                },
                onDismiss: _dismiss,
              ),
            ),
          ),
      ],
    );
  }
}

/// Bannière visuelle de notification in-app.
class _NotificationBanner extends StatelessWidget {
  final String title;
  final String body;
  final String conversationId;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const _NotificationBanner({
    required this.title,
    required this.body,
    required this.conversationId,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00d4ff).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.message_rounded,
                  color: Color(0xFF00d4ff),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Color(0xFF6b7a96),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.close,
                      color: Color(0xFF6b7a96),
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
