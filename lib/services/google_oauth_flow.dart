import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
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
///
/// [expect] indique le flux réellement en cours (ouvert par l'application).
/// Quand il est fourni, un retour arrivant sur un hôte OmniSMS autorisé est
/// reconnu **quel que soit le chemin** : c'est indispensable parce que la
/// variante « app » du backend redirige aujourd'hui vers la racine de la PWA
/// (`https://…vercel.app/?code=…`), et non vers `/auth/google/callback`.
/// Sans flux en cours, aucun lien n'est détourné.
GoogleCallback? parseGoogleCallback(Uri uri, {GoogleCallbackKind? expect}) {
  final params = _queryParams(uri);

  final kind = _callbackKindFromUri(uri) ?? _pendingFlowKind(uri, params, expect);
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

/// Détermine le type de callback (login / contacts) porté par une URI.
///
/// Deux formes sont acceptées, car `Uri.parse` ne les traite pas de la même
/// façon :
///
///   • schéma personnalisé `omnisms://auth/google/callback` — `auth` est
///     l'**autorité** (host) de l'URI, le chemin ne vaut que
///     `/google/callback`. La route n'est retrouvable qu'en recomposant
///     `host + path`. C'est le cas du deep link mobile renvoyé par le backend.
///   • `https://domaine/auth/google/callback` (App Links / web) : la route est
///     dans le chemin — ou dans le fragment quand le site est en hash routing.
///
/// Sans le cas `host + path`, AUCUN retour Google n'était reconnu sur mobile
/// (le lien était ignoré et l'utilisateur restait sur l'écran de connexion).
GoogleCallbackKind? _callbackKindFromUri(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final fragment =
      _fragmentPathSegments(uri).where((s) => s.isNotEmpty).toList();

  final candidates = <String>{
    '/${segments.join('/')}',
    if (fragment.isNotEmpty) '/${fragment.join('/')}',
    if (uri.host.isNotEmpty) ...{
      '/${[uri.host, ...segments].join('/')}',
      if (fragment.isNotEmpty) '/${[uri.host, ...fragment].join('/')}',
    },
  };

  // Le callback contacts est testé en premier sur TOUS les candidats :
  // `…/auth/google/contacts/callback` ne doit jamais être confondu avec
  // `…/auth/google/callback`.
  for (final path in candidates) {
    if (path.endsWith(ApiConfig.googleContactsCallbackPath)) {
      return GoogleCallbackKind.contacts;
    }
  }
  for (final path in candidates) {
    if (path.endsWith(ApiConfig.googleLoginCallbackPath)) {
      return GoogleCallbackKind.login;
    }
  }
  return null;
}

/// Reconnaît un retour OAuth pendant qu'un flux est en cours.
///
/// Conditions cumulatives, volontairement strictes :
///   1. un flux [expect] est ouvert par l'application (ou relancé à froid
///      dans la fenêtre de validité) ;
///   2. l'hôte fait partie de [ApiConfig.googleCallbackHosts] ;
///   3. l'URI porte bien la charge utile attendue (`code`/`error` pour le
///      login, `authorized`/`error` pour les contacts).
GoogleCallbackKind? _pendingFlowKind(
  Uri uri,
  Map<String, String> params,
  GoogleCallbackKind? expect,
) {
  if (expect == null) return null;
  if (!ApiConfig.isGoogleCallbackHost(uri.host)) return null;

  final hasError = (params['error'] ?? '').isNotEmpty;
  switch (expect) {
    case GoogleCallbackKind.contacts:
      if (params.containsKey('authorized') || hasError) {
        return GoogleCallbackKind.contacts;
      }
      return null;
    case GoogleCallbackKind.login:
      if ((params['code'] ?? '').isNotEmpty || hasError) {
        return GoogleCallbackKind.login;
      }
      return null;
  }
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

  // ── Suivi du flux (cold start) et anti-rejeu ─────────────────
  // Mêmes clés que la PWA (`omnisms_google_flow`) : un seul modèle mental.
  static const String _flowPrefsKey = 'omnisms_google_flow';
  static const String _flowPrefsAtKey = 'omnisms_google_flow_at';

  /// Durée pendant laquelle un retour est accepté après l'ouverture du
  /// navigateur (l'utilisateur peut mettre du temps à choisir son compte, et
  /// l'application peut être relancée par le lien).
  static const Duration flowValidity = Duration(minutes: 15);

  GoogleCallbackKind? _flowKind;
  DateTime? _flowStartedAt;

  /// Codes d'échange déjà consommés : un code est à usage unique côté backend.
  final Set<String> _consumedCodes = <String>{};
  static const int _maxConsumedCodes = 32;

  /// Type de flux attendu : celui en cours d'attente, ou celui ouvert avant
  /// un éventuel redémarrage de l'application (cold start).
  GoogleCallbackKind? get expectedKind {
    if (_pendingKind != null) return _pendingKind;
    final startedAt = _flowStartedAt;
    if (_flowKind == null || startedAt == null) return null;
    if (DateTime.now().difference(startedAt) > flowValidity) return null;
    return _flowKind;
  }

  /// Marque l'ouverture d'un flux Google (avant d'ouvrir le navigateur).
  ///
  /// Indispensable pour reconnaître le retour après un **lancement à froid** :
  /// Android recrée l'application pour livrer le lien, le completer en mémoire
  /// n'existe plus.
  Future<void> markFlowStarted(GoogleCallbackKind kind) async {
    _flowKind = kind;
    _flowStartedAt = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_flowPrefsKey, kind.name);
      await prefs.setInt(
          _flowPrefsAtKey, _flowStartedAt!.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ GoogleOAuthFlow: marqueur de flux non persisté ($e)');
    }
  }

  /// Oublie le flux en cours (fin de traitement ou déconnexion).
  Future<void> clearFlow() async {
    _flowKind = null;
    _flowStartedAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_flowPrefsKey);
      await prefs.remove(_flowPrefsAtKey);
    } catch (_) {}
  }

  void _clearFlowMarkerOnly() {
    _flowKind = null;
    _flowStartedAt = null;
  }

  Future<void> _restoreFlowMarker() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_flowPrefsKey);
      final at = prefs.getInt(_flowPrefsAtKey);
      if (name == null || at == null) return;
      _flowKind = GoogleCallbackKind.values
          .where((k) => k.name == name)
          .firstOrNull;
      _flowStartedAt = DateTime.fromMillisecondsSinceEpoch(at);
    } catch (_) {}
  }

  /// `true` quand l'écoute des deep links est active.
  bool get isListening => _subscription != null;

  /// Démarre l'écoute des deep links (idempotent).
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _restoreFlowMarker();

    try {
      // app_links émet le lien initial (cold start) puis les suivants.
      _subscription = AppLinks().uriLinkStream.listen(
        handleIncomingUri,
        onError: (Object e) => debugPrint('⚠️ GoogleOAuthFlow stream: $e'),
      );
    } catch (e) {
      debugPrint('⚠️ GoogleOAuthFlow: app_links indisponible ($e)');
    }

    if (kIsWeb) {
      // Sur web, seul le lien initial est fourni par app_links : on relit
      // l'URL courante (cas d'un retour Google sur l'URL HTTPS déployée).
      handleIncomingUri(Uri.base);
    }
  }

  /// Traite une URI entrante (deep link ou App Link).
  ///
  /// Exposée pour les tests et pour un éventuel relais manuel : c'est le seul
  /// point d'entrée des retours Google.
  void handleIncomingUri(Uri uri) {
    final callback = parseGoogleCallback(uri, expect: expectedKind);
    if (callback == null) return;

    // Anti-rejeu : le backend n'accepte un code qu'une seule fois. Un même
    // retour livré deux fois (deep link + App Link, ou reprise de l'app) ne
    // doit pas déclencher deux échanges.
    if (callback.code != null && callback.code!.isNotEmpty) {
      if (!_consumedCodes.add(callback.code!)) {
        debugPrint('🔗 Google callback ignoré (code déjà consommé)');
        return;
      }
      if (_consumedCodes.length > _maxConsumedCodes) {
        _consumedCodes.remove(_consumedCodes.first);
      }
    }

    debugPrint('🔗 Google callback reçu: $callback');

    final completer = _pending;
    if (completer != null && !completer.isCompleted && _pendingKind == callback.kind) {
      _pending = null;
      _pendingKind = null;
      // Le flux est terminé : on ne doit plus reconnaître de retour du même
      // type tant qu'un nouveau navigateur n'a pas été ouvert.
      _clearFlowMarkerOnly();
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
    _flowKind = null;
    _flowStartedAt = null;
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
