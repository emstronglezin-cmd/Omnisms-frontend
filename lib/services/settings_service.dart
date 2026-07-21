import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class SettingsService {
  final AuthService _authService = AuthService();

  // Keys for local storage
  static const String _notificationsKey = 'notifications_enabled';
  static const String _soundsKey = 'sounds_enabled';
  static const String _alertsKey = 'alerts_enabled';
  static const String _themeKey = 'theme_mode'; // 'light', 'dark', 'system'

  // Get user statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {
          'messagesSent': 0,
          'messagesReceived': 0,
          'totalContacts': 0,
          'activeGroups': 0,
        };
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/stats'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['stats'] ?? data;
      }
      return {
        'messagesSent': 0,
        'messagesReceived': 0,
        'totalContacts': 0,
        'activeGroups': 0,
      };
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      return {
        'messagesSent': 0,
        'messagesReceived': 0,
        'totalContacts': 0,
        'activeGroups': 0,
      };
    }
  }

  // Notification settings
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
    
    // Sync with backend
    try {
      final token = await _authService.getToken();
      if (token != null) {
        await http.put(
          Uri.parse('${ApiConfig.baseUrl}/api/settings/notifications'),
          headers: {
            ...ApiConfig.headers,
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'enabled': enabled}),
        ).timeout(ApiConfig.requestTimeout);
      }
    } catch (e) {
      debugPrint('Error syncing notification settings: $e');
    }
  }

  // Sound settings
  Future<bool> getSoundsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundsKey) ?? true;
  }

  Future<void> setSoundsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundsKey, enabled);
  }

  // Alert settings
  Future<bool> getAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alertsKey) ?? true;
  }

  Future<void> setAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertsKey, enabled);
  }

  // Theme settings
  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  // Get all settings
  Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'notifications': await getNotificationsEnabled(),
      'sounds': await getSoundsEnabled(),
      'alerts': await getAlertsEnabled(),
      'theme': await getThemeMode(),
    };
  }

  // Subscription status
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {
          'active': false,
          'plan': 'free',
          'expiresAt': null,
        };
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.subscriptionEndpoint}'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['subscription'] ?? data;
      }
      return {
        'active': false,
        'plan': 'free',
        'expiresAt': null,
      };
    } catch (e) {
      debugPrint('Error getting subscription status: $e');
      return {
        'active': false,
        'plan': 'free',
        'expiresAt': null,
      };
    }
  }
}
