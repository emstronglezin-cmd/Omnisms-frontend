import 'package:flutter/material.dart';
import 'dart:async';
import 'message_provider.dart';
import 'services/api_service.dart';

class ConversationProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  final ApiService _apiService = ApiService();
  StreamSubscription<Message>? _messageSubscription;
  bool _isLoading = false;
  String? _error;
  String? _currentContact;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Envoie un message via l'API
  Future<void> sendMessage(String sender, String content) async {
    if (_currentContact == null) return;

    _setLoading(true);
    _clearError();

    // Ajoute le message localement immédiatement pour une meilleure UX
    final message = Message(
      sender: sender,
      content: content,
      timestamp: DateTime.now(),
      isMe: sender == 'Moi',
    );
    _messages.add(message);
    notifyListeners();

    // Envoie le message au backend
    final success = await _apiService.sendMessage(_currentContact!, content);

    if (!success) {
      _setError('Erreur lors de l\'envoi du message');
      // Optionnel: retirer le message en cas d'échec
      _messages.removeLast();
      notifyListeners();
    }

    _setLoading(false);
  }

  /// Se connecte au WebSocket pour recevoir des messages en temps réel
  void connectToServer() {
    _messageSubscription?.cancel();
    _messageSubscription = _apiService.connectWebSocket().listen(
      (message) {
        _messages.add(message);
        notifyListeners();
      },
      onError: (error) {
        _setError('Erreur de connexion WebSocket: $error');
      },
    );
  }

  /// Récupère les messages depuis l'API
  Future<void> fetchMessages([String? contactName]) async {
    if (contactName != null) {
      _currentContact = contactName;
    }

    if (_currentContact == null) return;

    _setLoading(true);
    _clearError();

    try {
      final messages = await _apiService.getMessages(_currentContact!);
      _messages.clear();
      _messages.addAll(messages);
      notifyListeners();
    } catch (e) {
      _setError('Erreur lors du chargement des messages: $e');
    }

    _setLoading(false);
  }

  /// Ferme la connexion WebSocket
  void disconnect() {
    _messageSubscription?.cancel();
    _apiService.disconnectWebSocket();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
