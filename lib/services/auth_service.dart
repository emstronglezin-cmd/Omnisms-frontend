import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'google_deep_link_service.dart';
import '../config/api_config.dart';
import '../models/models.dart';

class AuthService {
  static const String _tokenKey  = 'auth_token';
  static const String _userIdKey = 'user_id';

  // ── Helpers d'erreur ─────────────────────────────────────────
  static String _friendlyError(dynamic e) {
    final s = e.toString();
    if (s.contains('TimeoutException') || s.contains('timeout')) {
      return 'Le serveur met du temps à répondre (démarrage en cours). Veuillez réessayer dans quelques secondes.';
    }
    if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('NetworkException')) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion internet.';
    }
    if (s.contains('FormatException') || s.contains('SyntaxError')) {
      return 'Réponse inattendue du serveur. Réessayez.';
    }
    if (s.contains('XMLHttpRequest') || s.contains('CORS')) {
      return 'Erreur de connexion au serveur (CORS). Contactez le support.';
    }
    return 'Erreur réseau. Réessayez.';
  }

  // ── Register ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        }),
      ).timeout(ApiConfig.wakeupTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['token'] != null) await _saveToken(data['token']);
        if (data['userId'] != null || data['user']?['id'] != null) {
          await _saveUserId(data['userId'] ?? data['user']['id']);
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Inscription réussie',
          'user': data['user'] != null ? UserModel.fromJson(data['user']) : null,
          'token': data['token'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? 'Erreur lors de l\'inscription',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Le serveur met du temps à répondre (démarrage). Réessayez dans 10 secondes.',
      };
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  // ── Login ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: ApiConfig.headers,
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(ApiConfig.wakeupTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['token'] != null) await _saveToken(data['token']);
        if (data['userId'] != null || data['user']?['id'] != null) {
          await _saveUserId(data['userId'] ?? data['user']['id']);
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Connexion réussie',
          'user': data['user'] != null ? UserModel.fromJson(data['user']) : null,
          'token': data['token'],
        };
      } else {
        // Retourne le message exact du backend (ex: "Identifiants invalides")
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? 'Email ou mot de passe incorrect',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Le serveur met du temps à répondre (démarrage). Réessayez dans 10 secondes.',
      };
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  /// Starts the backend-owned OAuth flow, exchanges its one-use callback code
  /// for the ordinary OmniSMS JWT, and stores it using the existing session keys.
  Future<Map<String, dynamic>> signInWithGoogle() async {
    if (kIsWeb) {
      return {
        'success': false,
        'message': 'La connexion Google nécessite l’application OmniSMS installée.',
      };
    }

    try {
      final callback = await GoogleDeepLinkService.instance.runAndWait(
        callbackPath: '/google/callback',
        startFlow: () async {
          final launched = await launchUrl(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authGoogleEndpoint}'),
            mode: LaunchMode.externalApplication,
          );
          if (!launched) throw StateError('Impossible d’ouvrir Google.');
        },
      );

      final oauthError = callback.queryParameters['error'];
      if (oauthError != null) {
        return {
          'success': false,
          'message': _googleErrorMessage(oauthError),
        };
      }
      final code = callback.queryParameters['code'];
      if (code == null || code.isEmpty) {
        return {'success': false, 'message': 'La réponse Google est incomplète.'};
      }

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authGoogleExchangeEndpoint}'),
            headers: ApiConfig.headers,
            body: jsonEncode({'code': code}),
          )
          .timeout(ApiConfig.requestTimeout);
      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data is Map && data['success'] == true && data['token'] is String) {
        final token = data['token'] as String;
        final rawUser = data['user'];
        if (rawUser is! Map<String, dynamic>) {
          return {'success': false, 'message': 'Impossible de récupérer votre profil.'};
        }
        final user = UserModel.fromJson(rawUser);
        await _saveToken(token);
        if (user.id.isNotEmpty) await _saveUserId(user.id);
        return {'success': true, 'user': user, 'token': token};
      }

      final codeError = data is Map ? (data['code'] ?? data['error'])?.toString() : null;
      return {
        'success': false,
        'message': _googleErrorMessage(codeError ?? 'GOOGLE_EXCHANGE_FAILED'),
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Connexion Google impossible. Vérifiez votre connexion puis réessayez.',
      };
    }
  }

  String _googleErrorMessage(String code) {
    switch (code) {
      case 'GOOGLE_NOT_CONFIGURED':
        return 'La connexion Google est momentanément indisponible.';
      case 'GOOGLE_OAUTH_DENIED':
        return 'La connexion Google a été annulée.';
      case 'GOOGLE_STATE_INVALID':
      case 'GOOGLE_IDENTITY_INVALID':
      case 'GOOGLE_IDENTITY_CONFLICT':
      case 'GOOGLE_EXCHANGE_CODE_INVALID':
      case 'GOOGLE_EXCHANGE_FAILED':
        return 'La connexion Google n’a pas abouti. Réessayez.';
      default:
        return 'Connexion Google impossible. Réessayez.';
    }
  }

  // ── Get current user ──────────────────────────────────────────
  Future<UserModel?> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/me'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data['user'] ?? data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Update profile ────────────────────────────────────────────
  Future<Map<String, dynamic>> updateProfile({
    String? name, String? email, String? phone, String? photoUrl,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Non authentifié'};
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/profile'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          if (name != null)     'name': name,
          if (email != null)    'email': email,
          if (phone != null)    'phone': phone,
          if (photoUrl != null) 'photoUrl': photoUrl,
        }),
      ).timeout(ApiConfig.requestTimeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Profil mis à jour'};
      }
      return {'success': false, 'message': data['message'] ?? 'Erreur'};
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  // ── Logout ────────────────────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  // ── Token storage ─────────────────────────────────────────────
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }
}
