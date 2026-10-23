import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'google_oauth_flow.dart';
import 'otp_service.dart';

class AuthService {
  static const String _tokenKey  = 'auth_token';
  static const String _userIdKey = 'user_id';

  /// Vérification OTP en attente — contient le numéro, l'UID et un éventuel
  /// jeton d'attente. NE CONTIENT JAMAIS le code OTP : celui-ci reste dans
  /// le champ de saisie, en mémoire vive, et n'est jamais persisté.
  static const String _pendingVerificationKey = 'pending_phone_verification';

  /// `true` quand `/api/me` a explicitement rejeté le jeton (401).
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

  /// Détecte si l'identifiant saisi est un numéro de téléphone.
  /// Même heuristique que la PWA (`login()` dans public/app.js) :
  ///   isPhone = /^[+\d\s\-()+]{7,20}$/ ET pas de « @ ».
  static bool isPhoneIdentifier(String identifier) {
    final v = identifier.trim();
    if (v.contains('@')) return false;
    return RegExp(r'^[+\d\s\-()+]{7,20}$').hasMatch(v);
  }

  /// Format de nom d'utilisateur accepté par le backend (PWA : register()).
  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_.-]{2,50}$');

  static bool isValidUsername(String username) =>
      _usernameRegex.hasMatch(username.trim());

  /// Message d'erreur lisible pour un nom d'utilisateur invalide.
  static String usernameHint() =>
      "Le nom d'utilisateur ne peut contenir que des lettres, chiffres, _ . - (2-50 caractères).";

  // ── Vérification OTP : décision, lecture, écriture ───────────────

  /// Numéro de téléphone associé à une réponse d'authentification.
  static String _phoneFromAuthResponse(Map<String, dynamic> data) {
    final direct = data['phone']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final user = data['user'];
    if (user is Map) {
      return (user['phone'] ?? '').toString().trim();
    }
    return '';
  }

  /// `true` si le SERVEUR exige la vérification du numéro avant d'ouvrir
  /// une session.
  ///
  /// Sources exclusives : `requiresOtp: true` (contrat `routes/otp.js`) ou
  /// `user.phoneVerified === false` (renvoyé par `/login` et l'échange
  /// Google). Jamais un état local, jamais l'écran affiché.
  static bool serverRequiresVerification(
    Map<String, dynamic> data, {
    required bool isSignup,
  }) {
    if (ApiConfig.otpPolicy == OtpPolicy.disabled) return false;

    final explicitFlag = data['requiresOtp'] == true;
    final user = data['user'];
    final serverSaysUnverified = user is Map && user['phoneVerified'] == false;

    if (ApiConfig.otpPolicy == OtpPolicy.alwaysAfterSignup && isSignup) {
      // On ne peut vérifier que ce qui existe : sans numéro, pas d'OTP.
      return _phoneFromAuthResponse(data).isNotEmpty;
    }
    return explicitFlag || serverSaysUnverified;
  }

  /// Enregistre la vérification en attente. Aucun jeton d'accès n'est écrit :
  /// la session reste fermée tant que le serveur n'a pas confirmé.
  Future<PendingVerification> _savePendingVerification(
    Map<String, dynamic> data, {
    required VerificationOrigin origin,
  }) async {
    final pending = PendingVerification(
      phone: PhoneFormatter.normalize(_phoneFromAuthResponse(data)),
      userId: (data['userId'] ?? (data['user'] is Map ? data['user']['id'] : null))
          ?.toString(),
      // Jeton D'ATTENTE éventuel : stocké ici, jamais comme jeton d'accès.
      pendingToken: data['token']?.toString(),
      origin: origin,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingVerificationKey, pending.toJsonString());
    return pending;
  }

  /// Vérification en attente restée d'une session précédente
  /// (application tuée, perte de réseau, retour arrière).
  Future<PendingVerification?> getPendingVerification() async {
    final prefs = await SharedPreferences.getInstance();
    return PendingVerification.fromJsonString(
      prefs.getString(_pendingVerificationKey),
    );
  }

  Future<void> clearPendingVerification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingVerificationKey);
  }

  // ── Register ─────────────────────────────────────────────────
  /// `username` est OBLIGATOIRE côté backend (validation renvoyée en 400 :
  /// « Le nom d'utilisateur est requis. »). La PWA l'envoie toujours —
  /// sans lui, l'inscription est impossible.
  Future<Map<String, dynamic>> register({
    required String name,
    required String password,
    required String username,
    String? email,
    String? phone,
  }) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) {
      return {'success': false, 'message': "Le nom d'utilisateur est requis."};
    }
    if (!isValidUsername(cleanUsername)) {
      return {'success': false, 'message': usernameHint()};
    }

    try {
      final body = <String, dynamic>{
        'name': name.trim(),
        'password': password,
        'username': cleanUsername,
      };
      if (phone != null && phone.trim().isNotEmpty) body['phone'] = phone.trim();
      if (email != null && email.trim().isNotEmpty) body['email'] = email.trim();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authRegisterEndpoint}'),
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      ).timeout(ApiConfig.wakeupTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Le serveur exige-t-il la vérification du numéro ?
        // Si oui : AUCUNE session n'est ouverte. Le jeton éventuellement
        // renvoyé est un jeton d'attente, conservé à part et jamais utilisé
        // comme jeton d'accès.
        if (serverRequiresVerification(data, isSignup: true)) {
          final pending = await _savePendingVerification(
            data,
            origin: VerificationOrigin.signup,
          );
          return {
            'success': true,
            'requiresOtp': true,
            'verification': pending,
            'message': data['message'] ?? 'Vérifiez votre numéro de téléphone.',
            'user': data['user'] != null ? UserModel.fromJson(data['user']) : null,
            'token': null,
          };
        }

        if (data['token'] != null) await _saveToken(data['token']);
        if (data['userId'] != null || data['user']?['id'] != null) {
          await _saveUserId(data['userId'] ?? data['user']['id']);
        }
        return {
          'success': true,
          'requiresOtp': false,
          'message': data['message'] ?? 'Inscription réussie',
          'user': data['user'] != null ? UserModel.fromJson(data['user']) : null,
          'token': data['token'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? "Erreur lors de l'inscription",
          'code': data['code'],
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
  /// Accepte un email OU un numéro de téléphone, comme la PWA :
  ///   body = isPhone ? { phone, password } : { email, password }
  Future<Map<String, dynamic>> login({
    String? identifier,
    String? email,
    String? password,
  }) async {
    final id = (identifier ?? email ?? '').trim();
    final pwd = password ?? '';

    if (id.isEmpty || pwd.isEmpty) {
      return {'success': false, 'message': 'Identifiant et mot de passe requis.'};
    }

    final body = isPhoneIdentifier(id)
        ? {'phone': id, 'password': pwd}
        : {'email': id, 'password': pwd};

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authLoginEndpoint}'),
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      ).timeout(ApiConfig.wakeupTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Compte existant dont le numéro n'a jamais été vérifié : le serveur
        // le signale (`phoneVerified: false`). On reprend le parcours de
        // vérification sans ouvrir la session.
        if (serverRequiresVerification(data, isSignup: false)) {
          final pending = await _savePendingVerification(
            data,
            origin: VerificationOrigin.login,
          );
          return {
            'success': true,
            'requiresOtp': true,
            'verification': pending,
            'message': 'Vérifiez votre numéro de téléphone.',
            'user': data['user'] != null ? UserModel.fromJson(data['user']) : null,
            'token': null,
          };
        }

        if (data['token'] != null) await _saveToken(data['token']);
        if (data['userId'] != null || data['user']?['id'] != null) {
          await _saveUserId(data['userId'] ?? data['user']['id']);
        }
        return {
          'success': true,
          'requiresOtp': false,
          'message': data['message'] ?? 'Connexion réussie',
          'user': data['user'] != null ? UserModel.fromJson(data['user']) : null,
          'token': data['token'],
        };
      } else {
        // Message exact du backend (ex: « Identifiants invalides. »).
        // Jamais « Session expirée » sur l'écran de connexion (cf. PWA).
        final raw = (data['message'] ?? data['error'] ?? '').toString();
        final isTokenNoise = raw.contains('Session expir') || raw.contains('TOKEN_EXPIRED');
        return {
          'success': false,
          'message': isTokenNoise || raw.isEmpty
              ? 'Identifiants incorrects. Vérifiez votre téléphone/email et mot de passe.'
              : raw,
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

      // Marqueur persistant : indispensable si Android relance l'application
      // pour livrer le lien (cold start) — voir GoogleOAuthFlow.markFlowStarted.
      await flow.markFlowStarted(GoogleCallbackKind.login);

      final opened = await flow
          .openExternal('${ApiConfig.baseUrl}${ApiConfig.authGoogleStartEndpoint}');
      if (!opened) {
        await flow.clearFlow();
        return {'success': false, 'message': GoogleAuthMessages.browserUnavailable};
      }

      final GoogleCallback callback;
      try {
        callback = await flow.waitFor(GoogleCallbackKind.login);
      } on TimeoutException {
        await flow.clearFlow();
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

      // Le code est à usage unique : le flux est terminé, quel que soit le
      // résultat. On ne doit plus reconnaître de retour du même type.
      await GoogleOAuthFlow.instance.clearFlow();

      if (response.statusCode == 200 && data['token'] != null) {
        // Compte Google neuf (ou ancien compte non vérifié) : le serveur
        // décide (`requiresOtp` / `phoneVerified: false`). Aucune session
        // ouverte tant qu'il ne confirme pas.
        if (serverRequiresVerification(data, isSignup: true)) {
          final pending = await _savePendingVerification(
            data,
            origin: VerificationOrigin.google,
          );
          return {
            'success': true,
            'requiresOtp': true,
            'verification': pending,
            'message': 'Vérifiez votre numéro de téléphone.',
            'user': data['user'] != null
                ? UserModel.fromJson(
                    Map<String, dynamic>.from(data['user'] as Map))
                : null,
            'token': null,
          };
        }

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

  /// Ouvre la session APRÈS confirmation de la vérification par le serveur.
  ///
  /// C'est le seul point où le jeton renvoyé par `verify-otp` devient un
  /// jeton d'accès. Le jeton d'attente éventuel est effacé dans la foulée.
  Future<void> completeVerification({
    required String token,
    String? userId,
  }) async {
    await _saveToken(token);
    _sessionExpired = false;
    if (userId != null && userId.isNotEmpty) await _saveUserId(userId);
    await clearPendingVerification();
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
  /// GET /api/me — même route que la PWA (`refreshUserProfile()`).
  /// Repli sur /api/auth/me si la première route n'est pas disponible.
  Future<UserModel?> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      http.Response response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.meEndpoint}'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 404) {
        response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authMeEndpoint}'),
          headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        ).timeout(ApiConfig.requestTimeout);
      }

      if (response.statusCode == 200) {
        _sessionExpired = false;
        final data = jsonDecode(response.body);
        final raw = (data is Map && data['user'] != null) ? data['user'] : data;
        return UserModel.fromJson(Map<String, dynamic>.from(raw as Map));
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
  /// PUT /api/me/profile — mêmes champs que la PWA (`saveProfile()`) :
  /// name, username, phone, email, password (mot de passe optionnel, ≥ 8).
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? username,
    String? password,
    String? photoUrl,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Non authentifié'};

      final body = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
      if (email != null && email.trim().isNotEmpty) body['email'] = email.trim();
      if (phone != null && phone.trim().isNotEmpty) body['phone'] = phone.trim();
      if (username != null && username.trim().isNotEmpty) {
        final u = username.trim();
        if (!isValidUsername(u)) {
          return {'success': false, 'message': usernameHint(), 'code': 'INVALID_USERNAME'};
        }
        body['username'] = u;
      }
      if (password != null && password.length >= 8) body['password'] = password;
      if (photoUrl != null && photoUrl.isNotEmpty) body['avatar'] = photoUrl;

      if (body.isEmpty) {
        return {'success': false, 'message': 'Aucune modification'};
      }

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.meProfileEndpoint}'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      ).timeout(ApiConfig.requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // La PWA recharge le profil depuis /api/me après sauvegarde :
        // on fait la même chose pour rester synchronisé avec le serveur.
        UserModel? user;
        if (data is Map && data['user'] != null) {
          user = UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
        } else {
          user = await getCurrentUser();
        }
        return {
          'success': true,
          'message': (data is Map ? data['message'] : null) ?? 'Profil mis à jour',
          'user': user,
        };
      }

      final code = (data is Map ? data['code'] : null)?.toString();
      String message;
      if (code == 'USERNAME_EXISTS') {
        message = "Nom d'utilisateur déjà utilisé — choisissez-en un autre";
      } else if (code == 'INVALID_USERNAME') {
        message = usernameHint();
      } else {
        message = (data is Map ? (data['message'] ?? data['error']) : null) ?? 'Erreur';
      }
      return {'success': false, 'message': message, 'code': code};
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  // ── Upload avatar ─────────────────────────────────────────────
  /// POST /api/me/avatar (multipart, champ « avatar ») — idem PWA
  /// (`uploadAvatar()`), qui compresse l'image avant l'envoi.
  ///
  /// [bytes] + [filename] fonctionnent sur mobile comme sur web.
  /// [filePath] est une alternative pratique sur mobile (dart:io).
  Future<Map<String, dynamic>> uploadAvatar({
    List<int>? bytes,
    String? filename,
    String? filePath,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Non authentifié'};
      if ((bytes == null || bytes.isEmpty) && (filePath == null || filePath.isEmpty)) {
        return {'success': false, 'message': 'Aucune image sélectionnée'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.meAvatarEndpoint}'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.files.add(
        bytes != null && bytes.isNotEmpty
            ? http.MultipartFile.fromBytes(
                'avatar',
                bytes,
                filename: filename ?? 'avatar.jpg',
              )
            : await http.MultipartFile.fromPath(
                'avatar',
                filePath!,
                filename: filename ?? 'avatar.jpg',
              ),
      );

      final streamed = await request.send().timeout(ApiConfig.wakeupTimeout);
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final avatarUrl = (data is Map ? (data['avatarUrl'] ?? data['avatar']) : null)
            ?.toString();
        if (avatarUrl == null || avatarUrl.isEmpty) {
          return {'success': false, 'message': "URL de l'avatar manquante"};
        }
        // Resynchronisation depuis le serveur (idem PWA : refreshUserProfile()).
        final user = await getCurrentUser();
        return {'success': true, 'avatarUrl': avatarUrl, 'user': user};
      }

      return {
        'success': false,
        'message': (data is Map ? (data['message'] ?? data['error']) : null) ??
            "Échec de l'upload",
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Le serveur met du temps à répondre. Réessayez.',
      };
    } catch (e) {
      return {'success': false, 'message': _friendlyError(e)};
    }
  }

  // ── Delete account ────────────────────────────────────────────
  /// DELETE /api/me — idem PWA (`deleteAccount()`).
  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'Non authentifié'};

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.meEndpoint}'),
        headers: {...ApiConfig.headers, 'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.requestTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await logout();
        return {
          'success': true,
          'message': (data is Map ? data['message'] : null) ?? 'Compte supprimé',
        };
      }
      return {
        'success': false,
        'message': (data is Map ? (data['message'] ?? data['error']) : null) ??
            'Erreur lors de la suppression du compte',
      };
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
