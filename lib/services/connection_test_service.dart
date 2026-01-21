import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ConnectionTestService {
  static final ConnectionTestService _instance = ConnectionTestService._internal();
  factory ConnectionTestService() => _instance;
  ConnectionTestService._internal();

  /// Teste la connexion avec le backend
  Future<ConnectionTestResult> testConnection() async {
    try {
      // Test de l'endpoint de base
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        return ConnectionTestResult(
          isConnected: true,
          message: 'Connexion réussie au backend',
          statusCode: response.statusCode,
        );
      } else {
        return ConnectionTestResult(
          isConnected: false,
          message: 'Backend accessible mais endpoint /health non trouvé (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ConnectionTestResult(
        isConnected: false,
        message: 'Erreur de connexion: $e',
        statusCode: null,
      );
    }
  }

  /// Teste l'endpoint des contacts
  Future<ConnectionTestResult> testContactsEndpoint() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ConnectionTestResult(
          isConnected: true,
          message: 'Endpoint contacts accessible - ${data.length} contacts trouvés',
          statusCode: response.statusCode,
        );
      } else {
        return ConnectionTestResult(
          isConnected: false,
          message: 'Erreur endpoint contacts: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ConnectionTestResult(
        isConnected: false,
        message: 'Erreur endpoint contacts: $e',
        statusCode: null,
      );
    }
  }

  /// Teste l'endpoint des messages
  Future<ConnectionTestResult> testMessagesEndpoint() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}?contact=test'),
        headers: ApiConfig.defaultHeaders,
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ConnectionTestResult(
          isConnected: true,
          message: 'Endpoint messages accessible - ${data.length} messages trouvés',
          statusCode: response.statusCode,
        );
      } else {
        return ConnectionTestResult(
          isConnected: false,
          message: 'Erreur endpoint messages: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ConnectionTestResult(
        isConnected: false,
        message: 'Erreur endpoint messages: $e',
        statusCode: null,
      );
    }
  }

  /// Teste l'envoi d'un message
  Future<ConnectionTestResult> testSendMessageEndpoint() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sendMessageEndpoint}'),
        headers: ApiConfig.defaultHeaders,
        body: json.encode({
          'contact': 'test',
          'content': 'Message de test',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ConnectionTestResult(
          isConnected: true,
          message: 'Endpoint envoi message accessible',
          statusCode: response.statusCode,
        );
      } else {
        return ConnectionTestResult(
          isConnected: false,
          message: 'Erreur endpoint envoi message: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ConnectionTestResult(
        isConnected: false,
        message: 'Erreur endpoint envoi message: $e',
        statusCode: null,
      );
    }
  }

  /// Teste tous les endpoints
  Future<List<ConnectionTestResult>> testAllEndpoints() async {
    final results = <ConnectionTestResult>[];
    
    results.add(await testConnection());
    results.add(await testContactsEndpoint());
    results.add(await testMessagesEndpoint());
    results.add(await testSendMessageEndpoint());
    
    return results;
  }
}

class ConnectionTestResult {
  final bool isConnected;
  final String message;
  final int? statusCode;

  ConnectionTestResult({
    required this.isConnected,
    required this.message,
    this.statusCode,
  });
}
