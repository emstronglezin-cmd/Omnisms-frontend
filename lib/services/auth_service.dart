import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'google_oauth_flow.dart';

class AuthService {
  static const String _tokenKey  = 'auth_token';
  static const String _userIdKey = 'user_id';

  /// `true` quand `/api/auth/me` a explicitement rejeté le jeton (401).
  /// Sert à distinguer une session expirée d'un backend simplement endormi.
  bool _sessionExpired = false;
  bool get sessionExpired => _sessionExpired;

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

  // ── Google Sign-In (contrat backend : GET /api/auth/google) ───
  /// Flux imposé par le backend :
  ///   1. ouverture de `${baseUrl}/api/auth/google` dans le navigateur système ;
  ///   2. Google autorise → le backend redirige vers le deep link Flutter
  ///      `omnisms://auth/google/callback?code=…` (code à usage unique) ;
  ///   3. `POST /api/auth/google/exchange` → session OmniSMS (token + user),
  ///      stockée exactement comme pour le login email/mot de passe.
  ///
  /// Aucun token Google n'est manipulé côté Flutter.
  Future<Map<String, dynamic>> loginWithGoogle() async {
    final flow = GoogleOAuthFlow.instance;

    try {
      // Écouter le deep link AVANT d'ouvrir le navigateur.
      flow.clearPending();
      await flow.start();

      final opened = await flow
          .openExternal('${ApiConfig.baseUrl}${ApiConfig.authGoogleStartEndpoint}');
      if (!opened) {
        return {'success': false, 'message': GoogleAuthMessages.browserUnavailable};
      }

      final GoogleCallback callback;
      try {
        callback = await flow.waitFor(GoogleCallbackKind.login);
      } on TimeoutException {
        return {'success': false, 'message': GoogleAuthMessages.timeout};
      }

      if (!callback.isSuccess) {
        return {
          'success': false,
          'message': GoogleAuthMessages.forCallbackError(callback.error),
        };
      }

      return await _exchangeGoogleCode(callback.code!);
    } on GoogleFlowCancelledException {
      return {'success': false, 'message': GoogleAuthMessages.denied};
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  /// Échange le code Google contre la session OmniSMS et la persiste avec le
  /// même mécanisme que [login] (SharedPreferences : auth_token / user_id).
  Future<Map<String, dynamic>> _exchangeGoogleCode(String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authGoogleExchangeEndpoint}'),
            headers: ApiConfig.headers,
            body: jsonEncode({'code': code}),
          )
          .timeout(ApiConfig.wakeupTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['token'] != null) {
        await _saveToken(data['token'] as String);
        _sessionExpired = false;

        UserModel? user = data['user'] != null
            ? UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map))
            : null;

        final userId = user?.id.isNotEmpty == true
            ? user!.id
            : (data['userId'] ?? '').toString();
        if (userId.isNotEmpty) await _saveUserId(userId);

        // Profil complet si le backend n'a pas renvoyé l'utilisateur.
        user ??= await getCurrentUser();

        return {
          'success': true,
          'message': data['message'] ?? 'Connexion réussie',
          'user': user,
          'token': data['token'],
        };
      }

      return {
        'success': false,
        'message': GoogleAuthMessages.forExchangeError(
          response.statusCode,
          (data['code'] ?? '').toString(),
        ),
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Le serveur met du temps à répondre (démarrage). Réessayez dans 10 secondes.',
      };
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  /// Retour Google « à froid » : l'application a été relancée par le deep link.
  /// Non bloquant — n'attend que très brièvement un éventuel lien initial.
  Future<Map<String, dynamic>> recoverGoogleLoginIfPending() async {
    try {
      final callback = await GoogleOAuthFlow.instance
          .consumeBuffered(GoogleCallbackKind.login);
      if (callback == null) return {'success': false, 'message': ''};
      if (!callback.isSuccess) {
        return {
          'success': false,
          'message': GoogleAuthMessages.forCallbackError(callback.error),
        };
      }
      return await _exchangeGoogleCode(callback.code!);
    } on GoogleFlowCancelledException {
      return {'success': false, 'message': ''};
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
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
        _sessionExpired = false;
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data['user'] ?? data);
      }
      // 401 = jeton refusé par le backend → session réellement expirée.
      // Les autres codes (timeout, 5xx, backend endormi) ne déconnectent pas.
      _sessionExpired = response.statusCode == 401;
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
    _sessionExpired = false;
    // Un flux Google en cours ne doit pas survivre à la déconnexion.
    GoogleOAuthFlow.instance.clearPending();
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
