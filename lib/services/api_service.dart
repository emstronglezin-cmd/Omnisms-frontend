import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../message_provider.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  WebSocketChannel? _channel;
  StreamController<Message>? _messageStreamController;

  /// Récupère la liste des contacts depuis le backend
  Future<List<String>> getContacts() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(
            const Duration(seconds: 5), // Timeout réduit pour mode hors ligne
            onTimeout: () {
              throw TimeoutException('Connexion timeout');
            },
          );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      } else {
        throw Exception(
          'Erreur lors de la récupération des contacts: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Erreur API getContacts (mode hors ligne): $e');
      // Retourne une liste vide en cas d'erreur (sera géré par le provider)
      return [];
    }
  }

  /// Récupère les messages d'une conversation
  Future<List<Message>> getMessages(String contactName) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}?contact=$contactName',
            ),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Connexion timeout');
            },
          );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception(
          'Erreur lors de la récupération des messages: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Erreur API getMessages (mode hors ligne): $e');
      // Retourne une liste vide (sera géré par le provider)
      return [];
    }
  }

  /// Envoie un message via l'API
  Future<bool> sendMessage(String contactName, String content) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sendMessageEndpoint}'),
            headers: ApiConfig.defaultHeaders,
            body: json.encode({
              'contact': contactName,
              'content': content,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Connexion timeout');
            },
          );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Erreur API sendMessage (mode hors ligne): $e');
      // Retourne false mais ne crash pas
      return false;
    }
  }

  /// Se connecte au WebSocket pour recevoir des messages en temps réel
  Stream<Message> connectWebSocket() {
    if (_messageStreamController != null) {
      return _messageStreamController!.stream;
    }

    _messageStreamController = StreamController<Message>.broadcast();

    try {
      final uri = Uri.parse(ApiConfig.wsUrl);
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> messageData = json.decode(data);
            final message = Message.fromJson(messageData);
            _messageStreamController!.add(message);
          } catch (e) {
            debugPrint('Erreur parsing message WebSocket: $e');
          }
        },
        onError: (error) {
          debugPrint('Erreur WebSocket (mode hors ligne): $error');
          // Ne pas propager l'erreur pour éviter les crashes
        },
        onDone: () {
          debugPrint('Connexion WebSocket fermée');
          _messageStreamController?.close();
        },
        cancelOnError: false, // Ne pas annuler en cas d'erreur
      );
    } catch (e) {
      debugPrint('Impossible de connecter WebSocket (mode hors ligne): $e');
      // Ne pas crasher, retourner un stream vide
    }

    return _messageStreamController!.stream;
  }

  /// Ferme la connexion WebSocket
  void disconnectWebSocket() {
    try {
      _channel?.sink.close();
      _messageStreamController?.close();
      _messageStreamController = null;
    } catch (e) {
      debugPrint('Erreur déconnexion WebSocket: $e');
    }
  }

  /// Récupère la liste des groupes
  Future<List<String>> getGroups() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/groups'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      } else {
        throw Exception(
          'Erreur lors de la récupération des groupes: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Erreur API getGroups: $e');
      return [];
    }
  }

  /// Crée un nouveau groupe
  Future<String?> createGroup(String groupName) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/groups'),
            headers: ApiConfig.defaultHeaders,
            body: json.encode({'name': groupName}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['name'];
      } else {
        throw Exception(
          'Erreur lors de la création du groupe: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Erreur API createGroup: $e');
      return null;
    }
  }

  /// Récupère le statut de l'abonnement
  Future<String> getSubscriptionStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/subscription/status'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'];
      } else {
        throw Exception(
          'Erreur lors de la récupération du statut d'abonnement: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Erreur API getSubscriptionStatus: $e');
      return 'Free';
    }
  }

  /// Crée un nouvel abonnement
  Future<bool> createSubscription() async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/payments/create'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Erreur lors de la création de l'abonnement: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Erreur API createSubscription: $e');
      return false;
    }
  }
}
