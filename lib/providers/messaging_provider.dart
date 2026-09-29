import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/messaging_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';

/// MessagingProvider — Central state for conversations + messages.
///
/// Architecture:
///   _conversations     → List<ConversationModel>  (sorted newest-first)
///   _messagesMap       → Map<conversationId, List<MessageModel>>
///
/// Real-time: periodic polling every 5 seconds (Socket.IO pkg not installed).
/// On new message receipt: conversation bubbles to top, unread counter updated.
class MessagingProvider with ChangeNotifier {
  final MessagingService _messagingService = MessagingService();
  final AuthService _authService = AuthService();
  final SettingsService _settingsService = SettingsService();

  // ── Conversations list ──────────────────────────────────────
  List<ConversationModel> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationsError;

  // ── Per-conversation messages ──────────────────────────────
  final Map<String, List<MessageModel>> _messagesMap = {};
  final Map<String, bool> _messagesLoading = {};

  // ── Global state ───────────────────────────────────────────
  bool _isConnected = false;
  String? _currentUserId;

  // ── Polling timer ───────────────────────────────────────────
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 5);

  // ── Active conversation (for per-conv polling) ──────────────
  String? _activeConversationId;

  // ── Getters ─────────────────────────────────────────────────
  List<ConversationModel> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationsError => _conversationsError;
  bool get isConnected => _isConnected;

  List<MessageModel> getMessages(String conversationId) {
    return _messagesMap[conversationId] ?? [];
  }

  bool isLoadingMessages(String conversationId) {
    return _messagesLoading[conversationId] ?? false;
  }

  // Legacy compat
  bool get isLoading => _isLoadingConversations;
  String? get error => _conversationsError;

  // ── Constructor ─────────────────────────────────────────────
  MessagingProvider() {
    _init();
  }

  /// Initialisation interne.
  ///
  /// CORRECTION RACE CONDITION (Session 9) :
  /// On vérifie que le token d'authentification existe AVANT d'appeler
  /// loadConversations(). Si le token est absent au démarrage (auth pas encore
  /// prête — SharedPreferences async, Safari iOS plus lent), on ne charge pas.
  /// L'appel à reinitialize() depuis LoginScreen (après login) déclenchera
  /// l'initialisation complète.
  Future<void> _init() async {
    _currentUserId = await _authService.getUserId();

    // Vérifier que le token est disponible avant de charger les données
    final token = await _authService.getToken();
    if (token != null && token.isNotEmpty) {
      _isConnected = true;
      await loadConversations();
    }
    // Sinon : loadConversations() sera appelé via reinitialize() après login

    // Démarrer le polling dans tous les cas (il catch silencieusement les 401)
    _startPolling();
  }

  /// Réinitialise l'état après une connexion réussie.
  ///
  /// À appeler depuis LoginScreen/AuthProvider après la confirmation du login :
  ///   context.read<MessagingProvider>().reinitialize();
  ///
  /// Recharge l'userId, marque la connexion active, et charge les conversations.
  Future<void> reinitialize() async {
    _currentUserId = await _authService.getUserId();
    final token = await _authService.getToken();
    if (token != null && token.isNotEmpty) {
      _isConnected = true;
      await loadConversations();
    }
  }

  // ── Polling ──────────────────────────────────────────────────
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      await _pollConversations();
      if (_activeConversationId != null) {
        await _pollMessages(_activeConversationId!);
      }
    });
  }

  Future<void> _pollConversations() async {
    try {
      final updated = await _messagingService.getConversations();
      if (updated.isNotEmpty || _conversations.isNotEmpty) {
        // Détecter les conversations avec de nouveaux messages non lus
        // (unreadCount > 0 et pas la conversation active)
        final previousIds = {for (final c in _conversations) c.id: c.unreadCount ?? 0};
        _mergeConversations(updated);
        // Notifier si une conversation non-active a de nouveaux messages
        for (final conv in updated) {
          final prevUnread = previousIds[conv.id] ?? 0;
          final newUnread  = conv.unreadCount ?? 0;
          if (newUnread > prevUnread && conv.id != _activeConversationId) {
            final lastMsg = conv.lastMessage ?? 'Nouveau message';
            final convId  = conv.id;
            // Utiliser un messageId synthétique basé sur conv+timestamp pour dédup
            final syntheticId = '${convId}_${conv.lastMessageTime?.millisecondsSinceEpoch ?? 0}';
            await _dispatchNotificationRaw(
              messageId      : syntheticId,
              title          : conv.contactName.isNotEmpty ? conv.contactName : 'OmniSMS',
              body           : lastMsg.length > 80 ? '${lastMsg.substring(0, 80)}…' : lastMsg,
              conversationId : convId,
            );
          }
        }
      }
    } catch (_) {}
  }

  /// Dispatch notification avec paramètres directs (sans MessageModel).
  Future<void> _dispatchNotificationRaw({
    required String messageId,
    required String title,
    required String body,
    required String conversationId,
  }) async {
    try {
      final notifEnabled = await _settingsService.getNotificationsEnabled();
      if (!notifEnabled) return;
      debugPrint('[NOTIFICATION] message received (conv poll) — conv: $conversationId');
      await NotificationService.instance.show(
        messageId      : messageId,
        title          : title,
        body           : body,
        conversationId : conversationId,
        activeConvId   : _activeConversationId,
        notificationsOn: notifEnabled,
      );
      debugPrint('[NOTIFICATION] notification dispatched (conv poll) — conv: $conversationId');
    } catch (_) {}
  }

  Future<void> _pollMessages(String conversationId) async {
    try {
      final messages = await _messagingService.getConversationHistory(
        conversationId,
        currentUserId: _currentUserId,
      );
      if (messages.isNotEmpty) {
        // Fusionner les messages plutôt que remplacer pour éviter les
        // sauts de scroll : on ne remplace que si la liste est vide
        // ou si on a de nouveaux messages (plus récents que le dernier connu).
        final existing = _messagesMap[conversationId];
        if (existing == null || existing.isEmpty) {
          _messagesMap[conversationId] = messages;
          notifyListeners();
        } else {
          // Fusionner : ajouter uniquement les messages absents de la liste locale
          final existingIds = {for (final m in existing) m.id};
          final newMessages = messages.where((m) => !existingIds.contains(m.id)).toList();
          if (newMessages.isNotEmpty) {
            // Ajouter les nouveaux messages et retrier
            existing.addAll(newMessages);
            existing.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            notifyListeners();
            // ── Notifications pour les messages entrants (pas envoyés par moi) ──
            for (final msg in newMessages) {
              if (!msg.isMe) {
                await _dispatchNotification(msg, conversationId);
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Merge updated conversations into the list, preserving order (newest first).
  void _mergeConversations(List<ConversationModel> updated) {
    if (updated.isEmpty) return;

    final Map<String, ConversationModel> existing = {
      for (final c in _conversations) c.id: c,
    };

    for (final conv in updated) {
      existing[conv.id] = conv;
    }

    _conversations = existing.values.toList()
      ..sort((a, b) {
        final at = a.lastMessageTime;
        final bt = b.lastMessageTime;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

    notifyListeners();
  }

  /// Set the currently open conversation (for focused polling).
  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }

  // ── Load conversations list ──────────────────────────────────
  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    _conversationsError = null;
    notifyListeners();

    try {
      final convs = await _messagingService.getConversations();
      _conversations = convs;
      _isLoadingConversations = false;
      notifyListeners();
    } catch (e) {
      _conversationsError = 'Erreur chargement conversations: $e';
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  // ── Load messages for a conversation ────────────────────────
  Future<void> loadMessages(String conversationId) async {
    if (_messagesLoading[conversationId] == true) return;

    _messagesLoading[conversationId] = true;
    notifyListeners();

    try {
      // Refresh current user ID if needed
      _currentUserId ??= await _authService.getUserId();

      final messages = await _messagingService.getConversationHistory(
        conversationId,
        currentUserId: _currentUserId,
      );
      _messagesMap[conversationId] = messages;
      _messagesLoading[conversationId] = false;
      notifyListeners();
    } catch (e) {
      _conversationsError = 'Erreur chargement messages: $e';
      _messagesLoading[conversationId] = false;
      notifyListeners();
    }
  }

  // ── Send text message ────────────────────────────────────────
  Future<bool> sendTextMessage({
    required String receiverId,
    required String content,
    String? conversationId,
    String? contactId, // alias for receiverId (legacy compat)
  }) async {
    debugPrint('[DEBUG_SEND] MessagingProvider sendTextMessage called, receiverId=$receiverId, contactId=$contactId, convId=$conversationId, content=$content');
    final targetReceiver = receiverId.isNotEmpty ? receiverId : (contactId ?? '');
    debugPrint('[DEBUG_SEND] MessagingProvider targetReceiver=$targetReceiver, contentLen=${content.length}');
    if (targetReceiver.isEmpty) {
      debugPrint('[DEBUG_SEND] MessagingProvider ABORT — targetReceiver empty (receiverId empty and contactId null/empty)');
      return false;
    }

    try {
      _currentUserId ??= await _authService.getUserId();
      debugPrint('[DEBUG_SEND] MessagingProvider currentUserId=$_currentUserId, calling MessagingService');

      final message = await _messagingService.sendTextMessage(
        receiverId: targetReceiver,
        content: content,
        conversationId: conversationId,
        currentUserId: _currentUserId,
      );

      debugPrint('[DEBUG_SEND] MessagingProvider service returned message=${message?.id ?? "null"}');

      if (message != null) {
        // Add to local message list immediately (optimistic)
        final convId = conversationId ??
            (message.conversationId.isNotEmpty
                ? message.conversationId
                : _buildConversationId(_currentUserId ?? '', targetReceiver));

        debugPrint('[DEBUG_SEND] MessagingProvider adding to local map convId=$convId');
        if (!_messagesMap.containsKey(convId)) {
          _messagesMap[convId] = [];
        }
        _messagesMap[convId]!.add(message);

        // Update conversation last message
        _updateConversationLastMessage(convId, message);

        notifyListeners();

        // Refresh conversations after a brief delay
        Future.delayed(const Duration(seconds: 2), loadConversations);

        return true;
      }
      debugPrint('[DEBUG_SEND] MessagingProvider service returned null → fail');
      return false;
    } catch (e, st) {
      debugPrint('[DEBUG_SEND] MessagingProvider exception: $e\n$st');
      return false;
    }
  }

  /// Compute conversationId from two user IDs (same logic as backend).
  String _buildConversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return sorted.join('-');
  }

  /// Update the conversation in the list with the new last message.
  void _updateConversationLastMessage(
      String conversationId, MessageModel message) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final updated = _conversations[idx].copyWith(
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
      );
      _conversations.removeAt(idx);
      _conversations.insert(0, updated);
    }
  }

  // ── Send voice message ────────────────────────────────────────
  Future<bool> sendVoiceMessage({
    required String contactId,
    required dynamic audioFile,
    int? duration,
    String? conversationId,
  }) async {
    // CORRECTION (Session 9) : ne pas bloquer le web en mode navigateur.
    // Le web peut envoyer des messages vocaux via getUserMedia.
    // La restriction kIsWeb était trop agressive — on laisse passer.
    try {
      _currentUserId ??= await _authService.getUserId();
      final message = await _messagingService.sendVoiceMessage(
        receiverId: contactId,
        audioFile: audioFile,
        duration: duration,
        conversationId: conversationId,
        currentUserId: _currentUserId,
      );

      if (message != null) {
        final convId = conversationId ?? message.conversationId;
        if (!_messagesMap.containsKey(convId)) {
          _messagesMap[convId] = [];
        }
        _messagesMap[convId]!.add(message);
        _updateConversationLastMessage(convId, message);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('sendVoiceMessage error: $e');
      return false;
    }
  }

  // ── React to message ──────────────────────────────────────────
  Future<bool> reactToMessage(String messageId, String emoji) async {
    try {
      return await _messagingService.reactToMessage(messageId, emoji);
    } catch (e) {
      return false;
    }
  }

  // ── Delete message ────────────────────────────────────────────
  Future<bool> deleteMessage(String conversationId, String messageId) async {
    try {
      final success = await _messagingService.deleteMessage(messageId);
      if (success) {
        _messagesMap[conversationId]?.removeWhere((m) => m.id == messageId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  // ── Transcribe voice message ──────────────────────────────────
  Future<String?> transcribeMessage(String messageId) async {
    try {
      return await _messagingService.transcribeVoiceMessage(messageId);
    } catch (e) {
      return null;
    }
  }

  // ── Update transcription in local state ───────────────────────
  void updateMessageTranscription(
      String conversationId, String messageId, String transcription) {
    final messages = _messagesMap[conversationId];
    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] =
            messages[index].copyWith(transcription: transcription);
        notifyListeners();
      }
    }
  }

  // ── Inject an inbound message directly (e.g. from push notification / Socket.IO) ─
  /// Ajoute immédiatement un message entrant dans l'état local.
  /// Utilisé pour afficher un message reçu sans attendre le prochain cycle de polling.
  void injectInboundMessage(String conversationId, MessageModel message) {
    if (!_messagesMap.containsKey(conversationId)) {
      _messagesMap[conversationId] = [];
    }
    final existing = _messagesMap[conversationId]!;
    final alreadyPresent = existing.any((m) => m.id == message.id);
    if (!alreadyPresent) {
      existing.add(message);
      existing.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _updateConversationLastMessage(conversationId, message);
      notifyListeners();
      // ── Notification pour message entrant (si pas un message de moi) ──
      if (!message.isMe) {
        _dispatchNotification(message, conversationId);
      }
    }
  }

  // ── Dispatch notification for a new inbound message ────────────────
  /// Déclenche une notification système pour un nouveau message entrant.
  ///
  /// Règles :
  ///   • notifications activées dans les paramètres utilisateur
  ///   • permission système accordée
  ///   • messageId non encore notifié (déduplication dans NotificationService)
  ///   • utilisateur n'est pas déjà dans cette conversation
  Future<void> _dispatchNotification(MessageModel message, String conversationId) async {
    try {
      final notifEnabled = await _settingsService.getNotificationsEnabled();
      if (!notifEnabled) return;

      // Titre : nom de l'expéditeur si disponible, sinon ID/numéro tronqué
      String title = 'OmniSMS';
      if (message.senderId.isNotEmpty) {
        final sid = message.senderId;
        // Si c'est un numéro E.164, masquer les 4 derniers chiffres pour l'affichage
        title = sid.startsWith('+') && sid.length > 6
            ? '${sid.substring(0, sid.length - 4)}****'
            : sid;
      }

      // Corps : aperçu du message (max 80 chars)
      String body = message.content ?? 'Nouveau message';
      if (body.length > 80) body = '${body.substring(0, 80)}…';

      debugPrint('[NOTIFICATION] message received — conv: $conversationId, msg: ${message.id}');

      await NotificationService.instance.show(
        messageId      : message.id,
        title          : title,
        body           : body,
        conversationId : conversationId,
        activeConvId   : _activeConversationId,
        notificationsOn: notifEnabled,
      );

      debugPrint('[NOTIFICATION] notification dispatched — conv: $conversationId');
    } catch (e) {
      debugPrint('[NOTIFICATION] _dispatchNotification error: $e');
    }
  }

  // ── Add conversation to list (after contact add / group create) ─
  void addOrUpdateConversation(ConversationModel conversation) {
    final idx = _conversations.indexWhere((c) => c.id == conversation.id);
    if (idx != -1) {
      _conversations[idx] = conversation;
    } else {
      _conversations.insert(0, conversation);
    }
    notifyListeners();
  }

  // ── Mark conversation as read ─────────────────────────────────
  void markConversationAsRead(String conversationId) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      _conversations[idx] =
          _conversations[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  // ── Force refresh ─────────────────────────────────────────────
  Future<void> refresh() async {
    await loadConversations();
  }

  void clearError() {
    _conversationsError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
