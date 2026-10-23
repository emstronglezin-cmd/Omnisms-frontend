import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

/// Traduction des erreurs techniques en messages lisibles, en français.
///
/// RÈGLE APPLIQUÉE : on ne masque JAMAIS une erreur, on cesse simplement de
/// l'afficher *brute* à l'utilisateur. Le détail technique continue d'être
/// journalisé par les appelants (`debugPrint`) et par le gestionnaire global
/// de `main.dart`.
///
/// Cette fonction est volontairement PURE (aucun import Flutter, aucun effet
/// de bord) pour être testable unitairement.
String userMessage(Object? error, {String? fallback}) {
  if (error == null) return fallback ?? 'Une erreur est survenue.';

  final text = error.toString().trim();
  if (text.isEmpty) return fallback ?? 'Une erreur est survenue.';

  final lower = text.toLowerCase();

  // 1) Erreurs réseau / transport (les plus fréquentes sur mobile).
  if (error is SocketException ||
      error is TimeoutException ||
      lower.contains('socketexception') ||
      lower.contains('timeoutexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('connection closed') ||
      lower.contains('network is unreachable') ||
      lower.contains('no address associated with hostname') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('clientexception') ||
      lower.contains('unreachable')) {
    return 'Pas de connexion réseau. Vérifiez votre connexion puis réessayez.';
  }

  // 2) Réponses serveur identifiables.
  if (_hasStatus(lower, '401') || lower.contains('unauthorized')) {
    return 'Session expirée. Reconnectez-vous.';
  }
  if (_hasStatus(lower, '403') || lower.contains('forbidden')) {
    return 'Action refusée par le serveur.';
  }
  if (_hasStatus(lower, '404') || lower.contains('not found')) {
    return 'Ressource introuvable.';
  }
  if (_hasStatus(lower, '429')) {
    return 'Trop de tentatives. Patientez quelques instants.';
  }
  if (_hasStatus(lower, '500') ||
      _hasStatus(lower, '502') ||
      _hasStatus(lower, '503') ||
      _hasStatus(lower, '504') ||
      lower.contains('bad gateway') ||
      lower.contains('service unavailable')) {
    return 'Le serveur est momentanément indisponible. Réessayez.';
  }

  // 3) Erreurs de décodage / de typage : typiquement une réponse inattendue
  //    du serveur. Le détail reste dans les journaux.
  if (error is FormatException ||
      lower.contains('formatexception') ||
      lower.contains('is not a subtype of type') ||
      lower.contains('type \'') ||
      lower.contains('nosuchmethod') ||
      lower.contains('null check operator') ||
      lower.contains('bad state:')) {
    return fallback ?? 'Réponse inattendue du serveur. Réessayez.';
  }

  // 4) Message déjà lisible (envoyé tel quel par le backend, ex. « Numéro
  //    déjà utilisé ») : on le transmet, sans jamais dépasser une longueur
  //    raisonnable ni laisser passer une trace technique.
  final firstLine = text.split('\n').first.trim();
  if (!_looksTechnical(firstLine) && firstLine.length <= 200) {
    return firstLine;
  }

  return fallback ?? 'Une erreur est survenue. Réessayez.';
}

/// `true` si le texte ressemble à une sortie technique (exception, JSON,
/// URL, trace). Ces chaînes ne doivent jamais être affichées telles quelles.
bool _looksTechnical(String text) {
  final lower = text.toLowerCase();
  return lower.contains('exception') ||
      lower.contains('stack') ||
      lower.startsWith('http') ||
      lower.contains('{') ||
      lower.contains('}') ||
      lower.contains('<') ||
      lower.contains('&gt;') ||
      lower.contains('dart:') ||
      lower.contains('package:') ||
      lower.contains('null check') ||
      lower.contains('instance of');
}

/// Détecte un code HTTP dans un texte (« 500 », « statusCode: 500 »…).
bool _hasStatus(String lowerText, String code) {
  return lowerText.contains('statuscode: $code') ||
      lowerText.contains('status: $code') ||
      lowerText.contains('http $code') ||
      lowerText.contains(' $code ') ||
      lowerText.endsWith(code);
}
