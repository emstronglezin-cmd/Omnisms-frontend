import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../message_provider.dart';
import 'package:logger/logger.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  WebSocketChannel? _channel;
  StreamController<Message>? _messageStreamController;
  final Logger _logger = Logger();

  /// Récupère la liste des contacts depuis le backend
  Future<List<String>> getContacts() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      } else {
        throw Exception(
          'Erreur lors de la récupération des contacts: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('Erreur API getContacts: $e');
      // Retourne des contacts par défaut en cas d'erreur
      return ['Alice', 'Bob', 'Charlie'];
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
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception(
          'Erreur lors de la récupération des messages: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('Erreur API getMessages: $e');
      // Retourne des messages par défaut en cas d'erreur
      return _getDefaultMessages(contactName);
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
          .timeout(ApiConfig.requestTimeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      _logger.e('Erreur API sendMessage: $e');
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
      _channel = WebSocketChannel.connect(Uri.parse(ApiConfig.wsUrl));

      _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> messageData = json.decode(data);
            final message = Message.fromJson(messageData);
            _messageStreamController!.add(message);
          } catch (e) {
            _logger.e('Erreur lors du parsing du message WebSocket: $e');
          }
        },
        onError: (error) {
          _logger.e('Erreur WebSocket: $error');
          _messageStreamController!.addError(error);
        },
        onDone: () {
          _logger.i('Connexion WebSocket fermée');
          _messageStreamController!.close();
        },
      );
    } catch (e) {
      _logger.e('Erreur lors de la connexion WebSocket: $e');
      _messageStreamController!.addError(e);
    }

    return _messageStreamController!.stream;
  }

  /// Ferme la connexion WebSocket
  void disconnectWebSocket() {
    _channel?.sink.close();
    _messageStreamController?.close();
    _messageStreamController = null;
  }

  /// Messages par défaut en cas d'erreur de connexion
  List<Message> _getDefaultMessages(String contactName) {
    return [
      Message(
        sender: contactName,
        content: 'Salut, comment ça va ?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isMe: false,
      ),
      Message(
        sender: 'Moi',
        content: 'Ça va bien, merci ! Et toi ?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
        isMe: true,
      ),
      Message(
        sender: contactName,
        content: 'Je vais très bien, merci.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        isMe: false,
      ),
      Message(
        sender: 'Moi',
        content: 'Super !',
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        isMe: true,
      ),
    ];
  }

  /// Récupère la liste des groupes
  Future<List<String>> getGroups() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/groups'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      } else {
        throw Exception(
          'Erreur lors de la récupération des groupes: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('Erreur API getGroups: $e');
      return [];
    }
  }

  /// Crée un nouveau groupe
  Future<String?> createGroup(String groupName) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/groups'),
        headers: ApiConfig.defaultHeaders,
        body: json.encode({'name': groupName}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['name'];
      } else {
        throw Exception(
          'Erreur lors de la création du groupe: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('Erreur API createGroup: $e');
      return null;
    }
  }

  /// Récupère le statut de l'abonnement
  Future<String> getSubscriptionStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/subscription/status'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'];
      } else {
        throw Exception(
          'Erreur lors de la récupération du statut d’abonnement: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('Erreur API getSubscriptionStatus: $e');
      return 'Free';
    }
  }

  /// Crée un nouvel abonnement
  Future<bool> createSubscription() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/payments/create'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Erreur lors de la création de l’abonnement: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('Erreur API createSubscription: $e');
      return false;
    }
  }
}
