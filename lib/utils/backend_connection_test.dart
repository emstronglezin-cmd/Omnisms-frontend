import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Utility class to test all backend connections
/// Used for debugging and ensuring all endpoints are functional
class BackendConnectionTest {
  static const String tag = 'BackendConnectionTest';

  /// Test all backend endpoints
  static Future<Map<String, dynamic>> testAllEndpoints() async {
    final results = <String, dynamic>{};

    debugPrint('$tag: 🔍 Starting backend connectivity tests...');

    // 1. Health Check
    results['health'] = await _testHealthEndpoint();

    // 2. Contacts API
    results['contacts'] = await _testContactsEndpoint();

    // 3. Messages API
    results['messages'] = await _testMessagesEndpoint();

    // 4. Send Message API
    results['sendMessage'] = await _testSendMessageEndpoint();

    // 5. Transcription API
    results['transcription'] = await _testTranscriptionEndpoint();

    // 6. WebSocket (info only)
    results['websocket'] = {
      'url': ApiConfig.wsUrl,
      'status': 'Cannot test via HTTP (requires runtime connection)',
      'tested': false,
    };

    debugPrint('$tag: ✅ All tests completed');
    _printResults(results);

    return results;
  }

  /// Test health endpoint
  static Future<Map<String, dynamic>> _testHealthEndpoint() async {
    try {
      final url = '${ApiConfig.baseUrl}/health';
      debugPrint('$tag: Testing $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final success = response.statusCode == 200;
      debugPrint(
          '$tag: Health check: ${response.statusCode} ${success ? '✅' : '❌'}');

      return {
        'endpoint': '/health',
        'method': 'GET',
        'statusCode': response.statusCode,
        'success': success,
        'message': success
            ? 'Backend is healthy'
            : 'Backend health check failed',
      };
    } catch (e) {
      debugPrint('$tag: Health check error: $e');
      return {
        'endpoint': '/health',
        'method': 'GET',
        'statusCode': 0,
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// Test contacts endpoint
  static Future<Map<String, dynamic>> _testContactsEndpoint() async {
    try {
      final url = '${ApiConfig.baseUrl}/api/contacts';
      debugPrint('$tag: Testing $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      // 401 is expected (authentication required)
      final success = response.statusCode == 401 || response.statusCode == 200;
      debugPrint(
          '$tag: Contacts API: ${response.statusCode} ${success ? '⚠️ (auth required)' : '❌'}');

      return {
        'endpoint': '/api/contacts',
        'method': 'GET',
        'statusCode': response.statusCode,
        'success': success,
        'message': response.statusCode == 401
            ? 'Endpoint exists (authentication required)'
            : response.statusCode == 200
                ? 'Endpoint accessible'
                : 'Endpoint not found or error',
      };
    } catch (e) {
      debugPrint('$tag: Contacts API error: $e');
      return {
        'endpoint': '/api/contacts',
        'method': 'GET',
        'statusCode': 0,
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// Test messages endpoint
  static Future<Map<String, dynamic>> _testMessagesEndpoint() async {
    try {
      final url = '${ApiConfig.baseUrl}/api/messages';
      debugPrint('$tag: Testing $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      // 401 or 200 is expected
      final success = response.statusCode == 401 || response.statusCode == 200;
      debugPrint(
          '$tag: Messages API: ${response.statusCode} ${success ? '✅' : '❌'}');

      return {
        'endpoint': '/api/messages',
        'method': 'GET',
        'statusCode': response.statusCode,
        'success': success,
        'message': response.statusCode == 401
            ? 'Endpoint exists (authentication required)'
            : response.statusCode == 200
                ? 'Endpoint accessible'
                : response.statusCode == 404
                    ? 'Endpoint not implemented on backend'
                    : 'Endpoint error',
      };
    } catch (e) {
      debugPrint('$tag: Messages API error: $e');
      return {
        'endpoint': '/api/messages',
        'method': 'GET',
        'statusCode': 0,
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// Test send message endpoint
  static Future<Map<String, dynamic>> _testSendMessageEndpoint() async {
    try {
      final url = '${ApiConfig.baseUrl}/api/messages/send';
      debugPrint('$tag: Testing $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}), // Empty body to test endpoint existence
      ).timeout(const Duration(seconds: 10));

      // 400, 401 is expected (validation error or auth required)
      final success =
          response.statusCode == 400 || response.statusCode == 401;
      debugPrint(
          '$tag: Send Message API: ${response.statusCode} ${success ? '⚠️ (validation error)' : '❌'}');

      return {
        'endpoint': '/api/messages/send',
        'method': 'POST',
        'statusCode': response.statusCode,
        'success': success,
        'message': response.statusCode == 400
            ? 'Endpoint exists (validation error - expected)'
            : response.statusCode == 401
                ? 'Endpoint exists (authentication required)'
                : response.statusCode == 404
                    ? 'Endpoint not implemented on backend'
                    : 'Endpoint error',
      };
    } catch (e) {
      debugPrint('$tag: Send Message API error: $e');
      return {
        'endpoint': '/api/messages/send',
        'method': 'POST',
        'statusCode': 0,
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// Test transcription endpoint
  static Future<Map<String, dynamic>> _testTranscriptionEndpoint() async {
    try {
      final url = '${ApiConfig.baseUrl}/api/transcription';
      debugPrint('$tag: Testing $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}), // Empty body to test endpoint existence
      ).timeout(const Duration(seconds: 10));

      // 400, 401 is expected (validation error or auth required)
      final success =
          response.statusCode == 400 || response.statusCode == 401;
      debugPrint(
          '$tag: Transcription API: ${response.statusCode} ${success ? '⚠️ (validation error)' : '❌'}');

      return {
        'endpoint': '/api/transcription',
        'method': 'POST',
        'statusCode': response.statusCode,
        'success': success,
        'message': response.statusCode == 400
            ? 'Endpoint exists (validation error - expected)'
            : response.statusCode == 401
                ? 'Endpoint exists (authentication required)'
                : response.statusCode == 404
                    ? 'Endpoint not implemented on backend'
                    : 'Endpoint error',
      };
    } catch (e) {
      debugPrint('$tag: Transcription API error: $e');
      return {
        'endpoint': '/api/transcription',
        'method': 'POST',
        'statusCode': 0,
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  /// Print formatted results
  static void _printResults(Map<String, dynamic> results) {
    debugPrint('');
    debugPrint('$tag: ========================================');
    debugPrint('$tag: 📊 BACKEND CONNECTIVITY TEST RESULTS');
    debugPrint('$tag: ========================================');

    for (final entry in results.entries) {
      final name = entry.key;
      final data = entry.value as Map<String, dynamic>;

      debugPrint('');
      debugPrint('$tag: 📍 ${name.toUpperCase()}');
      debugPrint('$tag:    Endpoint: ${data['endpoint'] ?? data['url']}');
      debugPrint('$tag:    Method: ${data['method'] ?? 'N/A'}');
      debugPrint('$tag:    Status: ${data['statusCode'] ?? 'N/A'}');
      debugPrint(
          '$tag:    Success: ${data['success'] ?? false ? '✅' : '❌'}');
      debugPrint('$tag:    Message: ${data['message'] ?? data['status']}');
    }

    debugPrint('');
    debugPrint('$tag: ========================================');
    debugPrint('$tag: ✅ TEST SUITE COMPLETE');
    debugPrint('$tag: ========================================');
  }

  /// Quick test for a single endpoint
  static Future<bool> quickTest(String endpoint) async {
    try {
      final url = '${ApiConfig.baseUrl}$endpoint';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }
}
