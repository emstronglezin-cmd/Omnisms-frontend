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

    try {
      // Envoie le message au backend
      final success = await _apiService.sendMessage(_currentContact!, content);

      if (!success) {
        _setError('Message enregistré localement (mode hors ligne)');
        // Garder le message même en cas d'échec (mode hors ligne)
      }
    } catch (e) {
      debugPrint('Erreur envoi message (mode hors ligne): $e');
      _setError('Message enregistré localement (mode hors ligne)');
      // Garder le message quand même
    }

    _setLoading(false);
  }

  /// Se connecte au WebSocket pour recevoir des messages en temps réel
  void connectToServer() {
    try {
      _messageSubscription?.cancel();
      _messageSubscription = _apiService.connectWebSocket().listen(
        (message) {
          _messages.add(message);
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Erreur WebSocket (mode hors ligne): $error');
          // Ne pas afficher d'erreur critique, juste logger
        },
        cancelOnError: false, // Ne pas annuler en cas d'erreur
      );
    } catch (e) {
      debugPrint('Impossible de connecter WebSocket (mode hors ligne): $e');
      // Ne pas crasher, continuer en mode local
    }
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
      if (messages.isNotEmpty) {
        _messages.clear();
        _messages.addAll(messages);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur chargement messages (mode hors ligne): $e');
      // Mode hors ligne : afficher un message d'info mais ne pas crasher
      _setError('Mode hors ligne - Historique local');
      // Garder les messages existants
    }

    _setLoading(false);
  }

  /// Ferme la connexion WebSocket
  void disconnect() {
    try {
      _messageSubscription?.cancel();
      _apiService.disconnectWebSocket();
    } catch (e) {
      debugPrint('Erreur déconnexion: $e');
    }
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
