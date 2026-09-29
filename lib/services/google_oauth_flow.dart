import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';

/// Levée quand un flux Google en attente est annulé (ex : logout).
class GoogleFlowCancelledException implements Exception {
  const GoogleFlowCancelledException();

  @override
  String toString() => 'GoogleFlowCancelledException';
}

/// Type de callback Google reçu par l'application.
enum GoogleCallbackKind {
  /// `omnisms://auth/google/callback?code=…` (ou `?error=…`)
  login,

  /// `omnisms://auth/google/contacts/callback?authorized=1` (ou `?error=…`)
  contacts,
}

/// Résultat normalisé d'un deep link Google.
///
/// Aucun token Google n'arrive ici : le backend ne renvoie qu'un code
/// d'échange à usage unique (login) ou un drapeau d'autorisation (contacts).
class GoogleCallback {
  final GoogleCallbackKind kind;

  /// Code d'échange OmniSMS (login uniquement).
  final String? code;

  /// Code d'erreur backend stable (ex : `GOOGLE_OAUTH_DENIED`).
  final String? error;

  /// `true` quand Google Contacts a été autorisé (`authorized=1`).
  final bool authorized;

  const GoogleCallback({
    required this.kind,
    this.code,
    this.error,
    this.authorized = false,
  });

  bool get isSuccess =>
      kind == GoogleCallbackKind.login ? (code != null && code!.isNotEmpty) : authorized;

  bool get isDenied => error == 'GOOGLE_OAUTH_DENIED';

  @override
  String toString() =>
      'GoogleCallback(kind: $kind, hasCode: ${code != null}, error: $error, authorized: $authorized)';
}

/// Analyse une URI de callback Google.
///
/// Retourne `null` si l'URI ne correspond à aucun des deux callbacks définis
/// par le backend. Le schéma `omnisms://` (mobile) et `https://` (web / App
/// Links) sont tous les deux acceptés.
GoogleCallback? parseGoogleCallback(Uri uri) {
  final params = _queryParams(uri);

  GoogleCallbackKind? kind = _callbackKindFromPath(uri.pathSegments);
  // Web (hash routing) : la route peut se trouver dans le fragment.
  kind ??= _callbackKindFromPath(_fragmentPathSegments(uri));
  if (kind == null) return null;

  if (kind == GoogleCallbackKind.contacts) {
    final authorized = params['authorized'];
    return GoogleCallback(
      kind: GoogleCallbackKind.contacts,
      authorized: authorized == '1' || authorized == 'true',
      error: params['error'],
    );
  }

  return GoogleCallback(
    kind: GoogleCallbackKind.login,
    code: params['code'],
    error: params['error'],
  );
}

GoogleCallbackKind? _callbackKindFromPath(Iterable<String> segments) {
  final path = '/${segments.where((s) => s.isNotEmpty).join('/')}';
  if (path.endsWith(ApiConfig.googleContactsCallbackPath)) {
    return GoogleCallbackKind.contacts;
  }
  if (path.endsWith(ApiConfig.googleLoginCallbackPath)) {
    return GoogleCallbackKind.login;
  }
  return null;
}

List<String> _fragmentPathSegments(Uri uri) {
  final fragment = uri.fragment;
  if (fragment.isEmpty) return const <String>[];
  final qIndex = fragment.indexOf('?');
  final path = qIndex >= 0 ? fragment.substring(0, qIndex) : fragment;
  return path.split('/');
}

/// Query params : `?a=b` normal, plus le fragment (`#/x?a=b`) pour les
/// redirections web en mode hash routing.
Map<String, String> _queryParams(Uri uri) {
  final params = <String, String>{};
  try {
    params.addAll(uri.queryParameters);
  } catch (e) {
    debugPrint('⚠️ query params illisibles: $e');
  }
  final fragment = uri.fragment;
  final qIndex = fragment.indexOf('?');
  if (qIndex >= 0) {
    try {
      final fragmentQuery =
          Uri.splitQueryString(fragment.substring(qIndex + 1));
      fragmentQuery.forEach((key, value) {
        params.putIfAbsent(key, () => value);
      });
    } catch (e) {
      debugPrint('⚠️ query params (fragment) illisibles: $e');
    }
  }
  return params;
}

/// Messages utilisateur — jamais de stack trace, de token ou de détail OAuth.
class GoogleAuthMessages {
  static const String denied = 'Connexion Google annulée.';
  static const String timeout = 'Aucune réponse de Google. Réessayez.';
  static const String browserUnavailable =
      'Impossible d\'ouvrir le navigateur pour la connexion Google.';
  static const String notConfigured =
      'La connexion Google n\'est pas encore disponible. Utilisez votre email et votre mot de passe.';
  static const String sessionExpired = 'La session Google a expiré. Réessayez.';
  static const String identityConflict =
      'Ce compte Google est déjà lié à un autre compte OmniSMS.';
  static const String identityInvalid =
      'Compte Google non vérifié. Réessayez avec un autre compte.';
  static const String interrupted = 'Connexion Google interrompue. Réessayez.';
  static const String exchangeFailed =
      'Impossible de finaliser la connexion Google. Réessayez.';

  /// Erreur renvoyée par le deep link (`?error=…`).
  static String forCallbackError(String? code) {
    switch (code) {
      case 'GOOGLE_OAUTH_DENIED':
        return denied;
      case 'GOOGLE_NOT_CONFIGURED':
        return notConfigured;
      case 'GOOGLE_STATE_INVALID':
        return interrupted;
      case 'GOOGLE_IDENTITY_INVALID':
      case 'GOOGLE_IDENTITY_MISSING':
        return identityInvalid;
      case 'GOOGLE_IDENTITY_CONFLICT':
        return identityConflict;
      default:
        return exchangeFailed;
    }
  }

  /// Erreur renvoyée par `POST /api/auth/google/exchange`.
  static String forExchangeError(int? statusCode, String? code) {
    switch (code) {
      case 'GOOGLE_EXCHANGE_CODE_INVALID':
        return sessionExpired;
      case 'GOOGLE_NOT_CONFIGURED':
        return notConfigured;
      case 'GOOGLE_IDENTITY_CONFLICT':
        return identityConflict;
      case 'GOOGLE_IDENTITY_INVALID':
      case 'GOOGLE_IDENTITY_MISSING':
        return identityInvalid;
      case 'GOOGLE_OAUTH_DENIED':
        return denied;
      default:
        return statusCode == 503 ? notConfigured : exchangeFailed;
    }
  }
}

/// Messages utilisateur pour l'import Google Contacts.
class GoogleContactsMessages {
  static const String denied = 'Autorisation Google refusée.';
  static const String timeout = 'Aucune réponse de Google. Réessayez.';
  static const String browserUnavailable =
      'Impossible d\'ouvrir le navigateur pour l\'autorisation Google.';
  static const String notConfigured =
      'L\'import des contacts Google n\'est pas encore disponible.';
  static const String notConnected =
      'Vous devez être connecté pour importer vos contacts Google.';
  static const String authorizationRequired =
      'Autorisation Google requise. Réessayez.';
  static const String serviceUnavailable =
      'Google Contacts est temporairement indisponible. Réessayez.';
  static const String importFailed = 'Impossible d\'importer les contacts Google.';
  static const String success = 'Contacts importés';

  static String forCode(String? code, {String? fallback}) {
    switch (code) {
      case 'GOOGLE_OAUTH_DENIED':
        return denied;
      case 'GOOGLE_CONTACTS_PERMISSION_REQUIRED':
        return denied;
      case 'GOOGLE_NOT_CONFIGURED':
        return notConfigured;
      case 'GOOGLE_CONTACTS_AUTH_REQUIRED':
      case 'GOOGLE_TOKEN_EXPIRED':
      case 'GOOGLE_REFRESH_TOKEN_MISSING':
        return authorizationRequired;
      case 'GOOGLE_PEOPLE_API_UNAVAILABLE':
      case 'GOOGLE_ENCRYPTION_NOT_CONFIGURED':
        return serviceUnavailable;
      case 'GOOGLE_STATE_INVALID':
      case 'GOOGLE_CONTACTS_AUTH_FAILED':
      case 'GOOGLE_CONTACTS_ACCOUNT_MISMATCH':
        return authorizationRequired;
      case 'NO_TOKEN':
      case 'INVALID_TOKEN':
      case 'INVALID_SESSION':
        return notConnected;
      default:
        return fallback ?? importFailed;
    }
  }

  /// Résumé lisible des compteurs renvoyés par le backend.
  static String summary(Map<String, dynamic> counts) {
    int asInt(String key) {
      final value = counts[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    final imported = asInt('imported');
    final updated = asInt('updated');
    final matches = asInt('omnismsMatches');

    if (counts['empty'] == true || (imported == 0 && updated == 0)) {
      return 'Aucun nouveau contact à importer.';
    }

    final parts = <String>[];
    if (imported > 0) parts.add('$imported importé${imported > 1 ? 's' : ''}');
    if (updated > 0) parts.add('$updated mis à jour');
    if (matches > 0) parts.add('$matches sur OmniSMS');
    return parts.isEmpty ? success : parts.join(', ');
  }
}

/// Gère le mécanisme de retour Flutter imposé par le backend :
/// les deep links `omnisms://auth/google/...`.
///
/// Un seul point d'écoute pour les deux flux (login + contacts) afin de ne pas
/// créer deux systèmes OAuth parallèles.
class GoogleOAuthFlow {
  GoogleOAuthFlow._();

  static final GoogleOAuthFlow instance = GoogleOAuthFlow._();

  /// Délai accordé à l'utilisateur pour valider le consentement Google.
  static const Duration callbackTimeout = Duration(minutes: 5);

  StreamSubscription<Uri>? _subscription;
  bool _started = false;

  Completer<GoogleCallback>? _pending;
  GoogleCallbackKind? _pendingKind;
  GoogleCallback? _buffered;

  /// Démarre l'écoute des deep links (idempotent).
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      // app_links émet le lien initial (cold start) puis les suivants.
      _subscription = AppLinks().uriLinkStream.listen(
        _handleUri,
        onError: (Object e) => debugPrint('⚠️ GoogleOAuthFlow stream: $e'),
      );
    } catch (e) {
      debugPrint('⚠️ GoogleOAuthFlow: app_links indisponible ($e)');
    }

    if (kIsWeb) {
      // Sur web, seul le lien initial est fourni par app_links : on relit
      // l'URL courante (cas d'un retour Google sur l'URL HTTPS déployée).
      _handleUri(Uri.base);
    }
  }

  void _handleUri(Uri uri) {
    final callback = parseGoogleCallback(uri);
    if (callback == null) return;

    debugPrint('🔗 Google callback reçu: $callback');

    final completer = _pending;
    if (completer != null && !completer.isCompleted && _pendingKind == callback.kind) {
      _pending = null;
      _pendingKind = null;
      completer.complete(callback);
      return;
    }

    // Personne n'attend encore (ex : app relancée par le deep link).
    _buffered = callback;
  }

  /// Consomme un callback déjà reçu sans attendre (retour à froid).
  Future<GoogleCallback?> consumeBuffered(GoogleCallbackKind kind,
      {Duration wait = const Duration(milliseconds: 1200)}) async {
    await start();
    if (_buffered != null && _buffered!.kind == kind) {
      final callback = _buffered;
      _buffered = null;
      return callback;
    }

    if (wait <= Duration.zero) return null;

    // L'app vient d'être relancée par le lien : laisser le temps au plugin
    // de livrer le lien initial.
    final completer = Completer<GoogleCallback>();
    _pending = completer;
    _pendingKind = kind;
    try {
      return await completer.future.timeout(wait);
    } on TimeoutException {
      return null;
    } finally {
      if (_pending == completer) {
        _pending = null;
        _pendingKind = null;
      }
    }
  }

  /// Attend le callback du flux demandé.
  ///
  /// Lève [TimeoutException] si rien n'arrive avant [timeout].
  Future<GoogleCallback> waitFor(
    GoogleCallbackKind kind, {
    Duration timeout = callbackTimeout,
  }) async {
    await start();

    final buffered = _buffered;
    if (buffered != null && buffered.kind == kind) {
      _buffered = null;
      return buffered;
    }

    final completer = Completer<GoogleCallback>();
    _pending = completer;
    _pendingKind = kind;
    try {
      return await completer.future.timeout(timeout);
    } finally {
      if (_pending == completer) {
        _pending = null;
        _pendingKind = null;
      }
    }
  }

  /// Oublie tout callback en attente (évite de rejouer un code déjà consommé).
  void clearPending() {
    _buffered = null;
    final completer = _pending;
    _pending = null;
    _pendingKind = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(const GoogleFlowCancelledException());
    }
  }

  /// Ouvre une URL dans le navigateur système (nécessaire pour OAuth).
  Future<bool> openExternal(String url) async {
    final uri = Uri.parse(url);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('⚠️ openExternal: $e');
      try {
        return await launchUrl(uri);
      } catch (e2) {
        debugPrint('⚠️ openExternal (fallback): $e2');
        return false;
      }
    }
  }
}
