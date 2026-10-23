import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/models.dart';

/// Nature d'un échec OTP — sert à choisir le message et le comportement de
/// l'écran (ex. : démarrer un compte à rebours sur [OtpFailure.cooldown]).
enum OtpFailure {
  /// Code saisi incorrect (le backend renvoie `OTP_INVALID`).
  invalidCode,

  /// Code expiré — `OTP_EXPIRED` (410). Il faut en redemander un.
  expired,

  /// Trop de tentatives — `OTP_MAX_TRIES` (429). Le code est révoqué.
  tooManyAttempts,

  /// Aucun code en attente pour ce numéro — `OTP_NOT_FOUND` (404).
  noPendingCode,

  /// Renvoi trop rapproché — `OTP_COOLDOWN` (429 sur `send-otp`).
  cooldown,

  /// Les endpoints OTP ne sont pas disponibles (routes non montées).
  serviceUnavailable,

  /// Champs refusés par la validation serveur (`VALIDATION_ERROR`).
  validation,

  /// Réseau / délai dépassé.
  network,

  /// Réponse inattendue ou erreur serveur (5xx).
  server,

  /// Cas non cartographié — traité comme un échec.
  unknown,
}

/// Résultat d'une demande d'envoi de code.
class OtpSendResult {
  final bool ok;
  final String message;
  final OtpFailure? failure;

  /// Secondes à patienter avant un nouvel envoi (renvoi par le serveur
  /// lors d'un `OTP_COOLDOWN`, sinon valeur par défaut de l'API).
  final int cooldownSeconds;

  /// Code renvoyé par le serveur en environnement de développement
  /// (`NODE_ENV !== 'production'`). Jamais persisté, jamais journalisé en
  /// production, utilisé uniquement pour les tests d'intégration.
  final String? devCode;

  const OtpSendResult({
    required this.ok,
    required this.message,
    this.failure,
    this.cooldownSeconds = ApiConfig.otpResendCooldownSeconds,
    this.devCode,
  });

  const OtpSendResult.failure(OtpFailure failure, String message,
      {int cooldownSeconds = ApiConfig.otpResendCooldownSeconds})
      : this(
          ok: false,
          message: message,
          failure: failure,
          cooldownSeconds: cooldownSeconds,
        );
}

/// Résultat d'une vérification de code.
class OtpVerifyResult {
  final bool ok;
  final String message;
  final OtpFailure? failure;

  /// Jeton d'accès renvoyé par le serveur APRÈS vérification confirmée.
  /// `null` tant que le serveur n'a pas confirmé — aucune session n'est
  /// ouverte dans ce cas.
  final String? token;

  /// Utilisateur renvoyé par le serveur (drapeau `phoneVerified` inclus).
  final UserModel? user;

  /// Essais restants avant révocation du code (`triesRemaining`).
  final int? triesRemaining;

  const OtpVerifyResult({
    required this.ok,
    required this.message,
    this.failure,
    this.token,
    this.user,
    this.triesRemaining,
  });

  const OtpVerifyResult.failure(OtpFailure failure, String message,
      {int? triesRemaining})
      : this(
          ok: false,
          message: message,
          failure: failure,
          triesRemaining: triesRemaining,
        );
}

/// Normalisation des numéros — miroir du service serveur
/// (`services/phoneNormalizer.js`, fonction `simpleNormalize`) pour que le
/// numéro affiché à l'utilisateur avant envoi soit celui que le serveur
/// utilisera.
///
/// Le serveur reste seul maître de la normalisation finale : celle-ci n'a
/// qu'un but d'affichage et de validation préalable.
class PhoneFormatter {
  /// Indicatif par défaut : Burkina Faso (`DEFAULT_PHONE_COUNTRY = 'BF'`).
  static const String defaultCountryCode = '226';

  /// Retire la mise en forme et applique le préfixe international.
  ///
  ///   '+226 70 12 34 56' → '+22670123456'
  ///   '0022670123456'    → '+22670123456'
  ///   '70123456'         → '+22670123456'
  static String normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    var p = trimmed.replaceAll(RegExp(r'[\s\-().]'), '');
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    if (!p.startsWith('+')) p = '+$defaultCountryCode$p';
    return p;
  }

  /// Numéro valide au sens du serveur : E.164 (`^\+[1-9]\d{6,14}$`).
  static bool isValid(String raw) {
    final normalized = normalize(raw);
    return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(normalized);
  }

  /// Même souplesse que la validation serveur d'avant normalisation
  /// (`/^\+?[0-9\s\-().]{7,20}$/`) — utilisée par les formulaires pour ne
  /// pas rejeter ce que le serveur accepterait.
  static bool isAcceptable(String raw) {
    return RegExp(r'^\+?[0-9\s\-().]{7,20}$').hasMatch(raw.trim());
  }

  /// Masque partiellement un numéro pour l'affichage : '+22670•••56'.
  static String mask(String raw) {
    final n = normalize(raw);
    if (n.length < 7) return n;
    final head = n.substring(0, n.length - 5);
    final tail = n.substring(n.length - 2);
    return '$head•••$tail';
  }
}

/// Client des endpoints OTP du backend.
///
/// Règles respectées :
///   • aucun code n'est conservé après l'appel (ni champ, ni préférence,
///     ni journal) ;
///   • une seule requête d'envoi ou de vérification à la fois
///     (garde anti double soumission) ;
///   • toute réponse ambiguë est traitée comme un échec ;
///   • aucun secret, aucune clé d'API : seul le JWT OmniSMS est utilisé si
///     le serveur le demande.
class OtpService {
  OtpService({http.Client? client, String? Function()? tokenProvider})
      : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider;

  final http.Client _client;
  final String? Function()? _tokenProvider;

  bool _sendInFlight = false;
  bool _verifyInFlight = false;

  bool get isSendInFlight => _sendInFlight;
  bool get isVerifyInFlight => _verifyInFlight;

  Map<String, String> get _headers {
    final headers = Map<String, String>.from(ApiConfig.headers);
    final token = _tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Demande l'envoi d'un code par SMS.
  ///
  /// [phone] est normalisé avant envoi. [userId] est transmis quand le
  /// compte existe déjà côté serveur (après inscription), conformément au
  /// contrat `POST /api/auth/send-otp { phone, userId? }`.
  Future<OtpSendResult> sendCode({
    required String phone,
    String? userId,
    String? pendingToken,
  }) async {
    // Anti double envoi : un second appel concurrent est refusé, pas mis en
    // file — l'écran garde la main pour réafficher le compte à rebours.
    if (_sendInFlight) {
      return const OtpSendResult.failure(
        OtpFailure.unknown,
        'Une demande est déjà en cours.',
      );
    }

    final normalized = PhoneFormatter.normalize(phone);
    if (!PhoneFormatter.isValid(phone)) {
      return const OtpSendResult.failure(
        OtpFailure.validation,
        'Numéro de téléphone invalide. Utilisez le format international, par exemple +22670123456.',
      );
    }

    _sendInFlight = true;
    try {
      final body = <String, dynamic>{
        'phone': normalized,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
        if (pendingToken != null && pendingToken.isNotEmpty)
          'pendingToken': pendingToken,
      };

      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authSendOtpEndpoint}'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.wakeupTimeout);

      final data = _decode(response.body);
      final code = (data?['code'] ?? '').toString();

      if (response.statusCode == 200 && data?['success'] == true) {
        return OtpSendResult(
          ok: true,
          message: (data?['message'] ?? 'Code envoyé.').toString(),
          devCode: data?['devCode']?.toString(),
        );
      }

      // 404 : route absente → le backend n'expose pas encore l'OTP.
      if (response.statusCode == 404 && code != 'OTP_NOT_FOUND') {
        return const OtpSendResult.failure(
          OtpFailure.serviceUnavailable,
          "Le service d'envoi de code est momentanément indisponible. Réessayez plus tard.",
        );
      }

      if (code == 'OTP_COOLDOWN' || response.statusCode == 429) {
        final cooldown = _asInt(data?['cooldown']) ??
            ApiConfig.otpResendCooldownSeconds;
        return OtpSendResult.failure(
          OtpFailure.cooldown,
          'Patientez $cooldown s avant de renvoyer un code.',
          cooldownSeconds: cooldown,
        );
      }

      if (code == 'VALIDATION_ERROR') {
        return OtpSendResult.failure(
          OtpFailure.validation,
          _firstFieldMessage(data) ?? 'Numéro de téléphone refusé par le serveur.',
        );
      }

      if (response.statusCode >= 500) {
        return const OtpSendResult.failure(
          OtpFailure.server,
          "Le serveur n'a pas pu envoyer le code. Réessayez dans un instant.",
        );
      }

      return OtpSendResult.failure(
        OtpFailure.server,
        (data?['error'] ?? data?['message'] ?? "Envoi du code impossible.")
            .toString(),
      );
    } on TimeoutException {
      return const OtpSendResult.failure(
        OtpFailure.network,
        'Le serveur met du temps à répondre (démarrage). Réessayez dans quelques secondes.',
      );
    } catch (e) {
      return OtpSendResult.failure(
        OtpFailure.network,
        _networkMessage(e),
      );
    } finally {
      _sendInFlight = false;
    }
  }

  /// Transmet le code saisi au serveur pour vérification.
  ///
  /// Ne renvoie [OtpVerifyResult.ok] que si le serveur confirme
  /// ET fournit un jeton d'accès : c'est la seule porte d'entrée de la
  /// session.
  Future<OtpVerifyResult> verifyCode({
    required String phone,
    required String code,
    String? userId,
    String? pendingToken,
  }) async {
    if (_verifyInFlight) {
      return const OtpVerifyResult.failure(
        OtpFailure.unknown,
        'Une vérification est déjà en cours.',
      );
    }

    final normalized = PhoneFormatter.normalize(phone);
    final cleaned = code.trim();

    if (cleaned.isEmpty) {
      return const OtpVerifyResult.failure(
        OtpFailure.validation,
        'Saisissez le code reçu par SMS.',
      );
    }
    if (!RegExp(r'^\d{4,8}$').hasMatch(cleaned)) {
      return const OtpVerifyResult.failure(
        OtpFailure.validation,
        'Le code doit contenir uniquement des chiffres.',
      );
    }

    _verifyInFlight = true;
    try {
      final body = <String, dynamic>{
        'phone': normalized,
        'code': cleaned,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
        if (pendingToken != null && pendingToken.isNotEmpty)
          'pendingToken': pendingToken,
      };

      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authVerifyOtpEndpoint}'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.wakeupTimeout);

      final data = _decode(response.body);
      final errorCode = (data?['code'] ?? '').toString();

      // Succès : il faut le drapeau serveur ET un jeton. Sans jeton, la
      // vérification n'est pas considérée comme acquise.
      if (response.statusCode == 200 &&
          data?['success'] == true &&
          data?['token'] != null) {
        UserModel? user;
        final rawUser = data?['user'];
        if (rawUser is Map) {
          user = UserModel.fromJson(Map<String, dynamic>.from(rawUser));
        }
        return OtpVerifyResult(
          ok: true,
          message:
              (data?['message'] ?? 'Numéro vérifié.').toString(),
          token: data!['token'].toString(),
          user: user,
        );
      }

      switch (errorCode) {
        case 'OTP_INVALID':
          final remaining = _asInt(data?['triesRemaining']);
          return OtpVerifyResult.failure(
            OtpFailure.invalidCode,
            remaining != null && remaining > 0
                ? 'Code incorrect. Il vous reste $remaining essai${remaining > 1 ? 's' : ''}.'
                : 'Code incorrect.',
            triesRemaining: remaining,
          );
        case 'OTP_EXPIRED':
          return const OtpVerifyResult.failure(
            OtpFailure.expired,
            'Code expiré. Demandez un nouveau code.',
          );
        case 'OTP_MAX_TRIES':
          return const OtpVerifyResult.failure(
            OtpFailure.tooManyAttempts,
            'Trop de tentatives. Demandez un nouveau code.',
          );
        case 'OTP_NOT_FOUND':
          return const OtpVerifyResult.failure(
            OtpFailure.noPendingCode,
            'Aucun code en attente pour ce numéro. Demandez un nouveau code.',
          );
        case 'VALIDATION_ERROR':
          return OtpVerifyResult.failure(
            OtpFailure.validation,
            _firstFieldMessage(data) ?? 'Code refusé par le serveur.',
          );
      }

      // 404 hors OTP_NOT_FOUND = route non montée côté serveur.
      if (response.statusCode == 404) {
        return const OtpVerifyResult.failure(
          OtpFailure.serviceUnavailable,
          'Le service de vérification est momentanément indisponible. Réessayez plus tard.',
        );
      }

      if (response.statusCode >= 500) {
        return const OtpVerifyResult.failure(
          OtpFailure.server,
          "Le serveur n'a pas pu vérifier le code. Réessayez dans un instant.",
        );
      }

      // Réponse 200 mais sans jeton : on échoue fermé.
      return OtpVerifyResult.failure(
        OtpFailure.server,
        "Le serveur n'a pas confirmé la vérification. Réessayez.",
      );
    } on TimeoutException {
      return const OtpVerifyResult.failure(
        OtpFailure.network,
        'Le serveur met du temps à répondre (démarrage). Réessayez dans quelques secondes.',
      );
    } catch (e) {
      return OtpVerifyResult.failure(OtpFailure.network, _networkMessage(e));
    } finally {
      _verifyInFlight = false;
    }
  }

  void dispose() => _client.close();

  // ── Helpers ─────────────────────────────────────────────────────
  static Map<String, dynamic>? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _firstFieldMessage(Map<String, dynamic>? data) {
    final fields = data?['fields'];
    if (fields is List && fields.isNotEmpty) {
      final first = fields.first;
      if (first is Map && first['msg'] != null) return first['msg'].toString();
    }
    return null;
  }

  static String _networkMessage(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion internet.';
    }
    if (s.contains('FormatException')) {
      return 'Réponse inattendue du serveur. Réessayez.';
    }
    return 'Erreur réseau. Réessayez.';
  }
}
