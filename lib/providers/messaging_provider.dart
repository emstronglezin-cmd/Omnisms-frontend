import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/messaging_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_service.dart';

/// MessagingProvider — Central state for conversations + messages.
///
/// Architecture:
///   _conversations     → List<ConversationModel>  (sorted newest-first)
///   _messagesMap       → Map<conversationId, List<MessageModel>>
///
/// Real-time: Socket.IO (RealtimeService) + polling de secours toutes les
/// 5 secondes. Le socket n'est pas qu'une optimisation : c'est lui qui
/// maintient la session de présence côté backend, donc c'est lui qui évite
/// qu'un message destiné à cet utilisateur parte en SMS.
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

  // ── Temps réel (Socket.IO) ──────────────────────────────────
  StreamSubscription<Map<String, dynamic>>? _realtimeSubscription;

  // ── Envois : suivi des échecs récupérables et anti-doublons ─
  /// Charge utile des messages en échec, pour un renvoi explicite.
  final Map<String, _PendingSend> _pendingSends = <String, _PendingSend>{};

  /// Identifiants de messages déjà injectés (événements Socket.IO dupliqués).
  final Set<String> _knownMessageIds = <String>{};

  /// Garde anti-double envoi : `receiverId|contenu` → horodatage.
  ///
  /// Un événement dupliqué (double clic, touche Entrée maintenue, reprise
  /// d'une file d'attente) ne doit pas produire deux messages — donc
  /// potentiellement deux SMS facturés.
  final Map<String, DateTime> _recentSends = <String, DateTime>{};
  static const Duration _sendDedupWindow = Duration(seconds: 3);

  /// Dernière route décidée par le backend (`OMNISMS` / `INFOBIP`).
  String? _lastSendRoute;

  /// `true` si le dernier envoi est réellement parti en SMS.
  bool _lastSendSmsFallback = false;

  // ── Getters ─────────────────────────────────────────────────
  List<ConversationModel> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationsError => _conversationsError;
  bool get isConnected => _isConnected;

  List<MessageModel> getMessages(String conversationId) {
    return _messagesMap[conversationId] ?? [];
  }

  /// Route retenue par le backend lors du dernier envoi
  /// (`OMNISMS` = interne, `INFOBIP` = SMS). `null` si inconnue.
  String? get lastSendRoute => _lastSendRoute;

  /// `true` si le dernier message envoyé est parti en SMS (destinataire sans
  /// session active côté backend au moment de l'envoi).
  bool get lastSendSmsFallback => _lastSendSmsFallback;

  /// `true` quand le socket temps réel est connecté : la présence de
  /// l'utilisateur est alors active côté backend.
  bool get isRealtimeConnected => RealtimeService.instance.isConnected;

  bool isLoadingMessages(String conversationId) {
    return _messagesLoading[conversationId] ?? false;
  }

  // Legacy compat
  bool get isLoading => _isLoadingConversations;
  String? get error => _conversationsError;

  // ── Constructor ─────────────────────────────────────────────
  MessagingProvider() {
    _init();
    _realtimeSubscription =
        RealtimeService.instance.messageStream.listen(_handleRealtimeMessage);
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
        final previousIds = {for (final c in _conversations) c.id: c.unreadCount};
        _mergeConversations(updated);
        // Notifier si une conversation non-active a de nouveaux messages
        for (final conv in updated) {
          final prevUnread = previousIds[conv.id] ?? 0;
          final newUnread  = conv.unreadCount;
          if (newUnread > prevUnread && conv.id != _activeConversationId) {
            final lastMsg = conv.lastMessage ?? 'Nouveau message';
            final convId  = conv.id;
            // Utiliser un messageId synthétique basé sur conv+timestamp pour dédup
            final syntheticId = '${convId}_${conv.lastMessageTime?.millisecondsSinceEpoch ?? 0}';
            await _dispatchNotificationRaw(
              messageId      : syntheticId,
              title          : conv.displayName.isNotEmpty ? conv.displayName : 'OmniSMS',
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
    final previous = _activeConversationId;
    _activeConversationId = conversationId;
    if (previous != null && previous != conversationId) {
      RealtimeService.instance.leaveConversation(previous);
    }
    if (conversationId != null) {
      RealtimeService.instance.joinConversation(conversationId);
    }
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
    if (targetReceiver.isEmpty) {
      debugPrint('[DEBUG_SEND] MessagingProvider ABORT — targetReceiver empty');
      return false;
    }

    _currentUserId ??= await _authService.getUserId();

    final result = await _sendToBackend(
      receiverId: targetReceiver,
      content: content,
      conversationId: conversationId,
    );

    // Un envoi dupliqué n'est pas un échec : le message existe déjà.
    if (result.duplicated) {
      debugPrint('[DEBUG_SEND] envoi identique déjà effectué → ignoré');
      return true;
    }

    // Décision de routage du backend : on la rend visible, on ne la devine pas.
    _lastSendRoute = result.route;
    _lastSendSmsFallback = result.isSmsFallback;
    notifyListeners();

    return result.isSuccess;
  }

  /// Appel réseau + gestion de l'échec (message conservé, renvoyable).
  Future<MessageSendResult> _sendToBackend({
    required String receiverId,
    required String content,
    String? conversationId,
  }) async {
    // Anti-double envoi : un même (destinataire, contenu) dans une fenêtre
    // courte est considéré comme un événement dupliqué.
    final dedupKey = '$receiverId|$content';
    final previous = _recentSends[dedupKey];
    final now = DateTime.now();
    if (previous != null && now.difference(previous) < _sendDedupWindow) {
      debugPrint('[MessagingProvider] envoi dupliqué ignoré ($dedupKey)');
      return const MessageSendResult(duplicated: true);
    }
    _recentSends[dedupKey] = now;
    _recentSends.removeWhere(
        (key, at) => now.difference(at) > const Duration(minutes: 1));

    MessageSendResult result;
    try {
      result = await _messagingService.sendTextMessageDetailed(
        receiverId: receiverId,
        content: content,
        conversationId: conversationId,
        currentUserId: _currentUserId,
      );
    } catch (e) {
      debugPrint('[DEBUG_SEND] exception: $e');
      result = const MessageSendResult(networkError: true);
    }

    if (result.isSuccess) {
      _addSentMessage(result.message!, conversationId, receiverId);
      return result;
    }

    // Échec : le message reste dans la conversation, marqué « échec », avec
    // un bouton « Renvoyer ». Rien n'est perdu silencieusement, et surtout on
    // ne suppose pas qu'un SMS est parti : le backend seul en décide.
    _addFailedMessage(
      receiverId: receiverId,
      content: content,
      conversationId: conversationId,
      networkError: result.networkError,
    );
    return result;
  }

  void _addSentMessage(
    MessageModel message,
    String? conversationId,
    String receiverId,
  ) {
    final convId = conversationId ??
        (message.conversationId.isNotEmpty
            ? message.conversationId
            : _buildConversationId(_currentUserId ?? '', receiverId));

    // Le backend peut renvoyer un conversationId canonique différent de l'ID
    // provisoire (résolution téléphone → UID). On le suit pour que les
    // messages suivants soient bien rattachés (fix P0 de la PWA).
    final canonicalId =
        message.conversationId.isNotEmpty ? message.conversationId : convId;

    _messagesMap.putIfAbsent(convId, () => <MessageModel>[]);
    final list = _messagesMap[convId]!;

    // Anti-doublon : le backend peut renvoyer un message déjà injecté par le
    // socket temps réel (même id). On remplace alors l'entrée locale.
    final existingIndex = list.indexWhere((m) => m.id == message.id);
    if (existingIndex >= 0) {
      list[existingIndex] = message;
    } else {
      list.add(message);
    }
    _knownMessageIds.add(message.id);

    if (canonicalId != convId) {
      _messagesMap[canonicalId] = List<MessageModel>.from(_messagesMap[convId]!);
      if (_activeConversationId == convId) _activeConversationId = canonicalId;
    }

    _updateConversationLastMessage(canonicalId, message);
    notifyListeners();

    // Refresh conversations after a brief delay
    Future.delayed(const Duration(seconds: 2), loadConversations);
  }

  /// Conserve un message non envoyé, visible et renvoyable.
  void _addFailedMessage({
    required String receiverId,
    required String content,
    String? conversationId,
    required bool networkError,
  }) {
    final tempId = 'pending-${DateTime.now().millisecondsSinceEpoch}';
    final convId = conversationId ??
        _buildConversationId(_currentUserId ?? '', receiverId);

    _pendingSends[tempId] = _PendingSend(
      receiverId: receiverId,
      content: content,
      conversationId: conversationId,
    );

    final message = MessageModel(
      id: tempId,
      tempId: tempId,
      conversationId: convId,
      senderId: _currentUserId ?? '',
      receiverId: receiverId,
      type: MessageType.text,
      content: content,
      status: MessageStatus.failed,
      timestamp: DateTime.now(),
      isMe: true,
    );

    _messagesMap.putIfAbsent(convId, () => <MessageModel>[]).add(message);
    notifyListeners();

    debugPrint(
        '[MessagingProvider] envoi en échec conservé ($tempId, réseau: $networkError)');
  }

  /// Renvoie un message resté en échec. Retourne `true` si le backend l'a
  /// accepté cette fois.
  Future<bool> retryMessage(String messageId) async {
    final pending = _pendingSends[messageId];
    if (pending == null) return false;

    _markMessageStatus(messageId, MessageStatus.sending);

    final result = await _sendToBackend(
      receiverId: pending.receiverId,
      content: pending.content,
      conversationId: pending.conversationId,
    );

    _lastSendRoute = result.route;
    _lastSendSmsFallback = result.isSmsFallback;

    if (result.isSuccess) {
      _pendingSends.remove(messageId);
      _removeMessage(messageId);
      _addSentMessage(
        result.message!,
        pending.conversationId,
        pending.receiverId,
      );
      notifyListeners();
      return true;
    }

    _markMessageStatus(messageId, MessageStatus.failed);
    notifyListeners();
    return false;
  }

  /// `true` si le message peut être renvoyé (envoi resté en échec).
  bool canRetry(String messageId) => _pendingSends.containsKey(messageId);

  void _markMessageStatus(String messageId, MessageStatus status) {
    for (final entry in _messagesMap.entries) {
      final index = entry.value.indexWhere((m) => m.id == messageId);
      if (index >= 0) {
        entry.value[index] = entry.value[index].copyWith(status: status);
        return;
      }
    }
  }

  void _removeMessage(String messageId) {
    for (final entry in _messagesMap.entries) {
      entry.value.removeWhere((m) => m.id == messageId);
    }
  }

  // ── Temps réel (Socket.IO) ────────────────────────────────────
  //
  // Le socket apporte les messages internes en temps réel. Les événements
  // peuvent arriver en double (reconnexion avec reprise d'état) : chaque
  // message est dédupliqué par identifiant avant insertion.

  void _handleRealtimeMessage(Map<String, dynamic> data) {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null || currentUserId.isEmpty) return;

      final message =
          MessageModel.fromJsonWithCurrentUser(data, currentUserId);
      if (message.id.isEmpty) return;

      // Nos propres envois sont déjà dans la liste (ajout local immédiat).
      if (message.isMe) return;

      final convId = message.conversationId.isNotEmpty
          ? message.conversationId
          : _buildConversationId(currentUserId, message.senderId);
      if (convId.isEmpty) return;

      final list = _messagesMap.putIfAbsent(convId, () => <MessageModel>[]);
      if (list.any((m) => m.id == message.id)) return; // événement dupliqué
      if (!_knownMessageIds.add(message.id)) {
        // Déjà vu lors d'une session précédente de la liste : on revérifie
        // tout de même la liste courante (qui peut avoir été rechargée).
        if (list.any((m) => m.id == message.id)) return;
      }

      list.add(message);
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _updateConversationLastMessage(convId, message);
      notifyListeners();

      debugPrint('[Realtime] message entrant injecté: ${message.id} ($convId)');

      // Conversation inconnue de la liste → on resynchronise.
      if (!_conversations.any((c) => c.id == convId)) {
        Future.delayed(const Duration(milliseconds: 500), loadConversations);
      }
    } catch (e) {
      debugPrint('[Realtime] message entrant illisible: $e');
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
  /// Flux identique à la PWA (`uploadVoiceMessage()`) :
  ///   1. bulle optimiste affichée immédiatement ;
  ///   2. POST /api/audio/upload ;
  ///   3. POST /api/messages/send (type audio) ;
  ///   4. remplacement de la bulle optimiste par le message réel.
  Future<bool> sendVoiceMessage({
    required String contactId,
    required dynamic audioFile,
    int? duration,
    String? conversationId,
    bool isGroup = false,
  }) async {
    try {
      _currentUserId ??= await _authService.getUserId();

      final convId = conversationId ?? '';
      final tempId = 'temp-audio-${DateTime.now().millisecondsSinceEpoch}';

      // ── 1. Bulle optimiste (état « envoi ») ──
      if (convId.isNotEmpty) {
        _messagesMap.putIfAbsent(convId, () => []);
        _messagesMap[convId]!.add(MessageModel(
          id: tempId,
          conversationId: convId,
          senderId: _currentUserId ?? '',
          type: MessageType.voice,
          content: null,
          audioUrl: '',
          duration: duration,
          status: MessageStatus.sending,
          timestamp: DateTime.now(),
          isMe: true,
          transcriptionStatus: 'pending',
        ));
        notifyListeners();
      }

      // ── 2 & 3. Upload puis envoi ──
      final result = await _messagingService.sendVoiceMessage(
        receiverId: contactId,
        audioFile: audioFile,
        duration: duration,
        conversationId: conversationId,
        currentUserId: _currentUserId,
        isGroup: isGroup,
      );

      if (result == null) {
        // Échec : retirer la bulle optimiste (comme la PWA).
        if (convId.isNotEmpty) {
          _messagesMap[convId]?.removeWhere((m) => m.id == tempId);
          notifyListeners();
        }
        return false;
      }

      final message = result['message'] as MessageModel;
      final resolvedUrl = (result['audioUrl'] ?? '').toString();
      final uploadDuration = (result['duration'] as num?)?.round();

      // ── 4. Remplacement de la bulle optimiste ──
      final canonicalId = message.conversationId.isNotEmpty
          ? message.conversationId
          : convId;

      if (convId.isNotEmpty) {
        final list = _messagesMap[convId];
        if (list != null) {
          final idx = list.indexWhere((m) => m.id == tempId);
          final real = message.copyWith(
            audioUrl: resolvedUrl.isNotEmpty ? resolvedUrl : message.audioUrl,
            duration: uploadDuration ?? message.duration,
            status: MessageStatus.sent,
            isMe: true,
          );
          if (idx != -1) {
            list[idx] = real;
          } else {
            list.add(real);
          }
        }
        if (canonicalId != convId) {
          _messagesMap[canonicalId] = List<MessageModel>.from(
            _messagesMap[convId] ?? [],
          );
        }
      }

      _updateConversationLastMessage(canonicalId, message);

      // Le serveur peut renvoyer un conversationId canonique différent du
      // provisoire (résolution téléphone → UID) : on le suit (fix P0 PWA).
      if (_activeConversationId == convId && canonicalId != convId) {
        _activeConversationId = canonicalId;
      }

      notifyListeners();

      // Rafraîchissement de fond (idem PWA : setTimeout(…, 1000)).
      Future.delayed(const Duration(seconds: 1), () async {
        await loadMessages(canonicalId.isNotEmpty ? canonicalId : convId);
      });
      return true;
    } catch (e) {
      debugPrint('sendVoiceMessage error: $e');
      return false;
    }
  }

  // ── Send group voice message (raccourci) ──────────────────────
  Future<bool> sendGroupVoiceMessage({
    required String groupId,
    required dynamic audioFile,
    int? duration,
  }) async {
    return sendVoiceMessage(
      contactId: groupId,
      audioFile: audioFile,
      duration: duration,
      conversationId: groupId,
      isGroup: true,
    );
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
  /// Même séquence que la PWA (`requestTranscription()`) :
  ///   • POST /api/audio/transcribe/:id  → lance le traitement
  ///   • GET  /api/audio/:id toutes les 3 s (40 tentatives max ≈ 120 s)
  ///   • statut local mis à jour : processing → done | error
  /// Le texte trouvé est renvoyé (null si échec/timeout).
  Future<String?> transcribeMessage(
    String messageId, {
    String? conversationId,
  }) async {
    final convId = conversationId ?? _findConversationOfMessage(messageId);
    if (convId == null) return null;

    _updateLocalMessage(
        convId, messageId, (m) => m.copyWith(transcriptionStatus: 'processing'));

    final started = await _messagingService.startTranscription(messageId);
    if (!started) {
      _updateLocalMessage(
          convId, messageId, (m) => m.copyWith(transcriptionStatus: 'error'));
      return null;
    }

    const maxAttempts = 40;
    const pollInterval = Duration(seconds: 3);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(pollInterval);
      final data = await _messagingService.getAudioMessage(messageId);

      final status = data?['transcriptionStatus']?.toString();
      final text = data?['transcription']?.toString() ?? '';

      if (status == 'done' && text.isNotEmpty) {
        _updateLocalMessage(
          convId,
          messageId,
          (m) => m.copyWith(
            transcription: text,
            transcriptionStatus: 'done',
          ),
        );
        return text;
      }

      if (status == 'error') {
        final err = data?['transcriptionError']?.toString();
        _updateLocalMessage(
          convId,
          messageId,
          (m) => m.copyWith(
            transcriptionStatus: 'error',
            transcriptionError: err,
          ),
        );
        return null;
      }
    }

    // Timeout 120 s : dernier contrôle puis état d'erreur (idem PWA).
    final finalData = await _messagingService.getAudioMessage(messageId);
    final finalText = finalData?['transcription']?.toString() ?? '';
    if (finalData?['transcriptionStatus']?.toString() == 'done' &&
        finalText.isNotEmpty) {
      _updateLocalMessage(
        convId,
        messageId,
        (m) => m.copyWith(transcription: finalText, transcriptionStatus: 'done'),
      );
      return finalText;
    }

    _updateLocalMessage(
        convId, messageId, (m) => m.copyWith(transcriptionStatus: 'error'));
    return null;
  }

  /// Retrouve la conversation qui contient [messageId].
  String? _findConversationOfMessage(String messageId) {
    for (final entry in _messagesMap.entries) {
      if (entry.value.any((m) => m.id == messageId)) return entry.key;
    }
    return null;
  }

  /// Applique [transform] au message [messageId] de la conversation [convId].
  void _updateLocalMessage(
    String convId,
    String messageId,
    MessageModel Function(MessageModel) transform,
  ) {
    final list = _messagesMap[convId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    list[idx] = transform(list[idx]);
    notifyListeners();
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
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}

/// Charge utile d'un message resté en échec, conservée pour un renvoi.
class _PendingSend {
  final String receiverId;
  final String content;
  final String? conversationId;

  const _PendingSend({
    required this.receiverId,
    required this.content,
    this.conversationId,
  });
}
