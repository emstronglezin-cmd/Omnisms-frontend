import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/messaging_service.dart';

class MessagingProvider with ChangeNotifier {
  final MessagingService _messagingService = MessagingService();

  Map<String, List<MessageModel>> _conversationsMessages = {};
  bool _isLoading = false;
  String? _error;
  bool _isConnected = false;

  List<MessageModel> getMessages(String contactId) {
    return _conversationsMessages[contactId] ?? [];
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _isConnected;

  MessagingProvider() {
    _initWebSocket();
  }

  void _initWebSocket() {
    _messagingService.connectWebSocket((message) {
      _addMessageToConversation(message);
    });
    _isConnected = true;
    notifyListeners();
  }

  void _addMessageToConversation(MessageModel message) {
    final contactId = message.isMe ? message.receiverId : message.senderId;
    if (contactId == null) return;

    if (!_conversationsMessages.containsKey(contactId)) {
      _conversationsMessages[contactId] = [];
    }
    _conversationsMessages[contactId]!.add(message);
    notifyListeners();
  }

  Future<void> loadMessages(String contactId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final messages = await _messagingService.getMessages(contactId: contactId);
      _conversationsMessages[contactId] = messages;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des messages: $e';
      _isLoading = false;
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
    required File audioFile,
    int? duration,
    String? conversationId,
  }) async {
    try {
      final message = await _messagingService.sendVoiceMessage(
        receiverId: contactId,
        audioFile: audioFile,
        duration: duration,
        conversationId: conversationId,
      );

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
      return await _messagingService.reactToMessage(messageId, emoji);
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

  @override
  void dispose() {
    _messagingService.disconnectWebSocket();
    super.dispose();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
