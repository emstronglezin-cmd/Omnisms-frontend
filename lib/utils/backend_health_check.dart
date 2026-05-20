import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// Classe pour vérifier la santé des connexions backend
class BackendHealthCheck {
  /// Test de connectivité avec le backend
  static Future<HealthCheckResult> checkBackendHealth() async {
    final results = <String, bool>{};
    final errors = <String, String>{};
    
    try {
      // 1. Test de connexion au backend principal
      debugPrint('🔍 Testing base URL connection: ${ApiConfig.baseUrl}');
      final baseUrlResult = await _testEndpoint(
        '${ApiConfig.baseUrl}/health',
        'Base URL Connection',
      );
      results['Base URL'] = baseUrlResult.success;
      if (!baseUrlResult.success) errors['Base URL'] = baseUrlResult.error ?? 'Unknown error';
      
      // 2. Test de l'endpoint API /api/contacts
      debugPrint('🔍 Testing contacts endpoint: ${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}');
      final contactsResult = await _testEndpoint(
        '${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}',
        'Contacts API',
      );
      results['Contacts API'] = contactsResult.success;
      if (!contactsResult.success) errors['Contacts API'] = contactsResult.error ?? 'Unknown error';
      
      // 3. Test de l'endpoint messages
      debugPrint('🔍 Testing messages endpoint: ${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}');
      final messagesResult = await _testEndpoint(
        '${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}',
        'Messages API',
      );
      results['Messages API'] = messagesResult.success;
      if (!messagesResult.success) errors['Messages API'] = messagesResult.error ?? 'Unknown error';
      
      // 4. Test de l'endpoint transcription
      debugPrint('🔍 Testing transcription endpoint: ${ApiConfig.baseUrl}${ApiConfig.transcriptionEndpoint}');
      final transcriptionResult = await _testEndpoint(
        '${ApiConfig.baseUrl}${ApiConfig.transcriptionEndpoint}',
        'Transcription API',
      );
      results['Transcription API'] = transcriptionResult.success;
      if (!transcriptionResult.success) errors['Transcription API'] = transcriptionResult.error ?? 'Unknown error';
      
      // 5. Test WebSocket (ne peut pas être testé facilement sans connexion réelle)
      debugPrint('ℹ️ WebSocket URL: ${ApiConfig.wsUrl}');
      results['WebSocket'] = true; // Assume OK, sera testé à la connexion
      
      final allSuccess = results.values.every((v) => v);
      
      return HealthCheckResult(
        success: allSuccess,
        results: results,
        errors: errors.isEmpty ? null : errors,
        message: allSuccess
            ? '✅ Tous les services backend sont opérationnels'
            : '⚠️ Certains services ont des problèmes',
      );
    } catch (e) {
      debugPrint('❌ Health check failed: $e');
      return HealthCheckResult(
        success: false,
        results: {'Global': false},
        errors: {'Global': e.toString()},
        message: '❌ Impossible de se connecter au backend',
      );
    }
  }
  
  /// Test un endpoint spécifique
  static Future<EndpointTestResult> _testEndpoint(
    String url,
    String name,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      ).timeout(const Duration(seconds: 10));
      
      final success = response.statusCode < 500; // 200-499 sont considérés comme OK
      
      if (success) {
        debugPrint('✅ $name: ${response.statusCode}');
      } else {
        debugPrint('❌ $name: ${response.statusCode}');
      }
      
      return EndpointTestResult(
        success: success,
        statusCode: response.statusCode,
        error: success ? null : 'Status code: ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('❌ $name: Connection failed - $e');
      return EndpointTestResult(
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// Afficher un rapport détaillé dans la console
  static void printDetailedReport(HealthCheckResult result) {
    debugPrint('\n' + '='*50);
    debugPrint('📊 BACKEND HEALTH CHECK REPORT');
    debugPrint('='*50);
    
    debugPrint('\n🌐 Configuration:');
    debugPrint('  Base URL: ${ApiConfig.baseUrl}');
    debugPrint('  WebSocket URL: ${ApiConfig.wsUrl}');
    
    debugPrint('\n📡 Endpoints Status:');
    result.results.forEach((name, success) {
      final icon = success ? '✅' : '❌';
      debugPrint('  $icon $name');
      if (!success && result.errors != null && result.errors![name] != null) {
        debugPrint('     Error: ${result.errors![name]}');
      }
    });
    
    debugPrint('\n📝 Summary:');
    debugPrint('  ${result.message}');
    debugPrint('  Success Rate: ${_calculateSuccessRate(result)}%');
    
    debugPrint('='*50 + '\n');
  }
  
  static double _calculateSuccessRate(HealthCheckResult result) {
    final total = result.results.length;
    final successful = result.results.values.where((v) => v).length;
    return total > 0 ? (successful / total * 100) : 0;
  }
}

/// Résultat du health check
class HealthCheckResult {
  final bool success;
  final Map<String, bool> results;
  final Map<String, String>? errors;
  final String message;
  
  HealthCheckResult({
    required this.success,
    required this.results,
    this.errors,
    required this.message,
  });
  
  Map<String, dynamic> toJson() => {
    'success': success,
    'results': results,
    'errors': errors,
    'message': message,
  };
}

/// Résultat du test d'un endpoint
class EndpointTestResult {
  final bool success;
  final int? statusCode;
  final String? error;
  
  EndpointTestResult({
    required this.success,
    this.statusCode,
    this.error,
  });
}
