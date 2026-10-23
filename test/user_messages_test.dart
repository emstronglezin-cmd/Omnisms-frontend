import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/utils/user_messages.dart';

/// Vérifie que les erreurs techniques ne sont JAMAIS affichées brutes à
/// l'utilisateur (exigence : plus de texte technique / trace dans l'UI).
void main() {
  group('userMessage — erreurs réseau', () {
    test('SocketException → message réseau lisible', () {
      final msg = userMessage(SocketException('Failed host lookup'));
      expect(msg, contains('Pas de connexion réseau'));
      expect(msg, isNot(contains('SocketException')));
    });

    test('TimeoutException → message réseau lisible', () {
      expect(userMessage(TimeoutException('after 0:00:30.000000')),
          contains('Pas de connexion réseau'));
    });

    test('erreur de connexion texte → message réseau', () {
      final msg = userMessage('ClientException: Connection refused');
      expect(msg, contains('Pas de connexion réseau'));
    });
  });

  group('userMessage — codes serveur', () {
    test('401 → session expirée', () {
      expect(userMessage('Exception: statusCode: 401'),
          contains('Session expirée'));
    });

    test('403 / 404 / 429 → messages dédiés', () {
      expect(userMessage('HttpException: 403'), contains('refusée'));
      expect(userMessage('HttpException: 404'), contains('introuvable'));
      expect(userMessage('HttpException: 429'), contains('Trop de tentatives'));
    });

    test('500 / 502 / 503 → serveur indisponible', () {
      expect(userMessage('statusCode: 500'), contains('indisponible'));
      expect(userMessage('statusCode: 502'), contains('indisponible'));
      expect(userMessage('Bad Gateway'), contains('indisponible'));
    });
  });

  group('userMessage — erreurs de décodage', () {
    test('exception de typage → message générique, jamais la trace', () {
      final msg = userMessage(
        "type 'String' is not a subtype of type 'int' of 'index'",
      );
      expect(msg, isNot(contains('subtype')));
      expect(msg, contains('Réponse inattendue'));
    });

    test('FormatException → message générique', () {
      expect(userMessage(const FormatException('Unexpected character')),
          contains('Réponse inattendue'));
    });
  });

  group('userMessage — messages déjà lisibles', () {
    test('un message métier du serveur est transmis tel quel', () {
      expect(userMessage('Numéro de téléphone déjà utilisé'),
          'Numéro de téléphone déjà utilisé');
    });

    test('un message serveur multi-lignes est réduit à la première ligne', () {
      expect(userMessage('Nom trop court\n    at some.place (dart:core)'),
          'Nom trop court');
    });

    test('un JSON ou du HTML n’est jamais recopié', () {
      expect(userMessage('{"error":"boom"}'), isNot(contains('{')));
      expect(userMessage('<html><body>502</body></html>'),
          isNot(contains('<')));
    });

    test('un message trop long est remplacé', () {
      final long = 'a' * 400;
      expect(userMessage(long), isNot(contains(long)));
    });
  });

  group('userMessage — repli', () {
    test('null → message par défaut', () {
      expect(userMessage(null), 'Une erreur est survenue.');
    });

    test('chaîne vide → message par défaut', () {
      expect(userMessage(''), 'Une erreur est survenue.');
    });

    test('le repli fourni est utilisé', () {
      expect(userMessage(Exception('x'), fallback: 'Envoi impossible'),
          'Envoi impossible');
    });
  });
}
