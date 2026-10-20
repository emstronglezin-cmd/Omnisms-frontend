import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/messaging_service.dart';

/// Provider optimisé avec pagination pour les messages
class PaginatedMessagingProvider with ChangeNotifier {
  final MessagingService _messagingService = MessagingService();

  // Cache des messages par conversation avec pagination
  final Map<String, List<MessageModel>> _conversationsMessages = {};
  final Map<String, bool> _hasMoreMessages = {};
  final Map<String, bool> _isLoadingMore = {};
  final Map<String, int> _currentPage = {};
  
  static const int _messagesPerPage = 50; // Charger 50 messages à la fois
  
  bool _isLoading = false;
  String? _error;
  bool _isConnected = false;

  List<MessageModel> getMessages(String contactId) {
    return _conversationsMessages[contactId] ?? [];
  }

  bool get isLoading => _isLoading;
  bool isLoadingMore(String contactId) => _isLoadingMore[contactId] ?? false;
  bool hasMore(String contactId) => _hasMoreMessages[contactId] ?? true;
  String? get error => _error;
  bool get isConnected => _isConnected;

  PaginatedMessagingProvider() {
    _initWebSocket();
  }

  void _initWebSocket() {
    try {
      _messagingService.connectWebSocket((message) {
        _addMessageToConversation(message);
      });
      _isConnected = true;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ WebSocket init error (non-blocking): $e');
      _isConnected = false;
    }
  }

  void _addMessageToConversation(MessageModel message) {
    final contactId = message.isMe ? message.receiverId : message.senderId;
    if (contactId == null) return;

    if (!_conversationsMessages.containsKey(contactId)) {
      _conversationsMessages[contactId] = [];
    }
    
    // Ajouter le nouveau message en haut (plus récent)
    _conversationsMessages[contactId]!.insert(0, message);
    notifyListeners();
  }

  /// Charger la première page de messages
  Future<void> loadMessages(String contactId, {bool refresh = false}) async {
    if (refresh) {
      _conversationsMessages[contactId] = [];
      _currentPage[contactId] = 0;
      _hasMoreMessages[contactId] = true;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final messages = await _messagingService.getMessages(
        contactId: contactId,
        limit: _messagesPerPage,
        offset: 0,
      );
      
      _conversationsMessages[contactId] = messages;
      _currentPage[contactId] = 1;
      _hasMoreMessages[contactId] = messages.length >= _messagesPerPage;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des messages: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger plus de messages (pagination)
  Future<void> loadMoreMessages(String contactId) async {
    if (_isLoadingMore[contactId] == true || _hasMoreMessages[contactId] == false) {
      return;
    }

    _isLoadingMore[contactId] = true;
    notifyListeners();

    try {
      final currentPage = _currentPage[contactId] ?? 1;
      final offset = currentPage * _messagesPerPage;
      
      final messages = await _messagingService.getMessages(
        contactId: contactId,
        limit: _messagesPerPage,
        offset: offset,
      );
      
      if (messages.isNotEmpty) {
        _conversationsMessages[contactId]?.addAll(messages);
        _currentPage[contactId] = currentPage + 1;
        _hasMoreMessages[contactId] = messages.length >= _messagesPerPage;
      } else {
        _hasMoreMessages[contactId] = false;
      }
      
      _isLoadingMore[contactId] = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement de plus de messages: $e';
      _isLoadingMore[contactId] = false;
      notifyListeners();
    }
  }

  Future<bool> sendTextMessage({
    required String contactId,
    required String content,
    String? conversationId,
  }) async {
    try {
      final message = await _messagingService.sendTextMessage(
        receiverId: contactId,
        content: content,
        conversationId: conversationId,
      );

      if (message != null) {
        _addMessageToConversation(message);
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Erreur lors de l\'envoi du message: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendVoiceMessage({
    required String contactId,
    required dynamic audioFile, // dynamic to avoid dart:io File on web
    int? duration,
    String? conversationId,
  }) async {
    if (kIsWeb) {
      debugPrint('⚠️ Voice messages not supported on web');
      return false;
    }
    try {
      final result = await _messagingService.sendVoiceMessage(
        receiverId: contactId,
        audioFile: audioFile,
        duration: duration,
        conversationId: conversationId,
      );

      final message = result?['message'] as MessageModel?;
      if (message != null) {
        _addMessageToConversation(message);
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Erreur lors de l\'envoi du message vocal: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> reactToMessage(String messageId, String emoji) async {
    try {
      final success = await _messagingService.reactToMessage(messageId, emoji);
      
      if (success) {
        // Update the message in cache
        for (final messages in _conversationsMessages.values) {
          final index = messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            messages[index] = messages[index].copyWith(reaction: emoji);
            notifyListeners();
            break;
          }
        }
      }
      
      return success;
    } catch (e) {
      _error = 'Erreur lors de la réaction: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMessage(String contactId, String messageId) async {
    try {
      final success = await _messagingService.deleteMessage(messageId);
      if (success) {
        _conversationsMessages[contactId]?.removeWhere((m) => m.id == messageId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Erreur lors de la suppression: $e';
      notifyListeners();
      return false;
    }
  }

  Future<String?> transcribeMessage(String messageId) async {
    try {
      return await _messagingService.transcribeVoiceMessage(messageId);
    } catch (e) {
      _error = 'Erreur lors de la transcription: $e';
      notifyListeners();
      return null;
    }
  }

  void updateMessageTranscription(String contactId, String messageId, String transcription) {
    final messages = _conversationsMessages[contactId];
    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        messages[index] = messages[index].copyWith(transcription: transcription);
        notifyListeners();
      }
    }
  }

  /// Clear cache for a specific conversation
  void clearConversationCache(String contactId) {
    _conversationsMessages.remove(contactId);
    _currentPage.remove(contactId);
    _hasMoreMessages.remove(contactId);
    _isLoadingMore.remove(contactId);
    notifyListeners();
  }

  /// Clear all caches
  void clearAllCaches() {
    _conversationsMessages.clear();
    _currentPage.clear();
    _hasMoreMessages.clear();
    _isLoadingMore.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    try {
      _messagingService.disconnectWebSocket();
    } catch (e) {
      debugPrint('⚠️ WebSocket disconnect error: $e');
    }
    super.dispose();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
