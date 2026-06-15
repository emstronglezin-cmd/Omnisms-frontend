import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Tests de connexion backend
class BackendConnectionTest {
  static Future<void> runAllTests() async {
    print('\n🔍 ==== TESTS BACKEND OMNISMS ====\n');
    
    await _testBaseUrl();
    await _testContactsEndpoint();
    await _testMessagesEndpoint();
    await _testTranscriptionEndpoint();
    await _testWebSocketUrl();
    
    print('\n✅ ==== TESTS TERMINÉS ====\n');
  }
  
  static Future<void> _testBaseUrl() async {
    print('🌐 Test Base URL: ${ApiConfig.baseUrl}');
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health'),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 || response.statusCode < 500) {
        print('   ✅ Base URL accessible (${response.statusCode})');
      } else {
        print('   ⚠️  Base URL répond mais erreur ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Base URL inaccessible: $e');
    }
  }
  
  static Future<void> _testContactsEndpoint() async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}';
    print('\n📇 Test Contacts Endpoint: $url');
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('   ✅ Contacts endpoint OK (200)');
        final data = jsonDecode(response.body);
        print('   📊 Response: ${data.toString().substring(0, 100)}...');
      } else if (response.statusCode == 401) {
        print('   ⚠️  Contacts endpoint OK mais auth requise (401)');
      } else {
        print('   ⚠️  Contacts endpoint répond: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Contacts endpoint erreur: $e');
    }
  }
  
  static Future<void> _testMessagesEndpoint() async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}';
    print('\n💬 Test Messages Endpoint: $url');
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('   ✅ Messages endpoint OK (200)');
      } else if (response.statusCode == 401) {
        print('   ⚠️  Messages endpoint OK mais auth requise (401)');
      } else {
        print('   ⚠️  Messages endpoint répond: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Messages endpoint erreur: $e');
    }
  }
  
  static Future<void> _testTranscriptionEndpoint() async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.transcriptionEndpoint}';
    print('\n🎤 Test Transcription Endpoint: $url');
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('   ✅ Transcription endpoint OK (200)');
      } else if (response.statusCode == 401 || response.statusCode == 404) {
        print('   ⚠️  Transcription endpoint accessible (${response.statusCode})');
      } else {
        print('   ⚠️  Transcription endpoint répond: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Transcription endpoint erreur: $e');
    }
  }
  
  static Future<void> _testWebSocketUrl() async {
    print('\n🔌 Test WebSocket URL: ${ApiConfig.wsUrl}');
    print('   ℹ️  WebSocket ne peut pas être testé via HTTP');
    print('   ℹ️  Test à faire à l\'exécution de l\'app');
    print('   ✅ URL configurée: ${ApiConfig.wsUrl}');
  }
  
  /// Test rapide inline
  static Future<Map<String, dynamic>> quickTest() async {
    final results = <String, dynamic>{};
    
    try {
      // Test base URL
      final baseResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health'),
      ).timeout(const Duration(seconds: 5));
      results['base_url'] = baseResponse.statusCode < 500;
      
      // Test contacts
      final contactsResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}'),
      ).timeout(const Duration(seconds: 5));
      results['contacts'] = contactsResponse.statusCode < 500;
      
      // Test messages
      final messagesResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}'),
      ).timeout(const Duration(seconds: 5));
      results['messages'] = messagesResponse.statusCode < 500;
      
    } catch (e) {
      results['error'] = e.toString();
    }
    
    return results;
  }
}

/// Fonction pour exécuter depuis main.dart
Future<void> testBackendConnections() async {
  await BackendConnectionTest.runAllTests();
}
