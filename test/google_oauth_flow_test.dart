import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/services/google_oauth_flow.dart';

/// Contrat backend : docs/GOOGLE_AUTH_FLUTTER.md
///   omnisms://auth/google/callback?code=<one-time-code>
///   omnisms://auth/google/callback?error=GOOGLE_OAUTH_DENIED
///   omnisms://auth/google/contacts/callback?authorized=1
///   omnisms://auth/google/contacts/callback?error=GOOGLE_OAUTH_DENIED
void main() {
  group('parseGoogleCallback — login', () {
    test('extrait le code d\'échange', () {
      final cb = parseGoogleCallback(
        Uri.parse('omnisms://auth/google/callback?code=abc123DEF_-'),
      );

      expect(cb, isNotNull);
      expect(cb!.kind, GoogleCallbackKind.login);
      expect(cb.code, 'abc123DEF_-');
      expect(cb.error, isNull);
      expect(cb.isSuccess, isTrue);
      expect(cb.isDenied, isFalse);
    });

    test('détecte le refus de l\'utilisateur', () {
      final cb = parseGoogleCallback(
        Uri.parse('omnisms://auth/google/callback?error=GOOGLE_OAUTH_DENIED'),
      );

      expect(cb, isNotNull);
      expect(cb!.kind, GoogleCallbackKind.login);
      expect(cb.code, isNull);
      expect(cb.error, 'GOOGLE_OAUTH_DENIED');
      expect(cb.isSuccess, isFalse);
      expect(cb.isDenied, isTrue);
    });

    test('accepte un retour HTTPS (App Links / web)', () {
      final cb = parseGoogleCallback(
        Uri.parse('https://omnisms.app/auth/google/callback?code=xyz'),
      );

      expect(cb, isNotNull);
      expect(cb!.kind, GoogleCallbackKind.login);
      expect(cb.code, 'xyz');
    });

    test('accepte un callback porté par le fragment (web hash routing)', () {
      final cb = parseGoogleCallback(
        Uri.parse('https://omnisms.app/#/auth/google/callback?code=frag1'),
      );

      expect(cb, isNotNull);
      expect(cb!.kind, GoogleCallbackKind.login);
      expect(cb.code, 'frag1');
    });

    test('un code vide n\'est pas un succès', () {
      final cb = parseGoogleCallback(
        Uri.parse('omnisms://auth/google/callback?code='),
      );

      expect(cb, isNotNull);
      expect(cb!.isSuccess, isFalse);
    });
  });

  group('parseGoogleCallback — contacts', () {
    test('autorisation accordée (authorized=1)', () {
      final cb = parseGoogleCallback(
        Uri.parse('omnisms://auth/google/contacts/callback?authorized=1'),
      );

      expect(cb, isNotNull);
      expect(cb!.kind, GoogleCallbackKind.contacts);
      expect(cb.authorized, isTrue);
      expect(cb.isSuccess, isTrue);
    });

    test('autorisation refusée', () {
      final cb = parseGoogleCallback(
        Uri.parse(
            'omnisms://auth/google/contacts/callback?error=GOOGLE_OAUTH_DENIED'),
      );

      expect(cb, isNotNull);
      expect(cb!.kind, GoogleCallbackKind.contacts);
      expect(cb.authorized, isFalse);
      expect(cb.isSuccess, isFalse);
      expect(cb.error, 'GOOGLE_OAUTH_DENIED');
    });

    test('le callback contacts n\'est jamais confondu avec le login', () {
      final cb = parseGoogleCallback(
        Uri.parse('omnisms://auth/google/contacts/callback?code=oops'),
      );

      expect(cb!.kind, GoogleCallbackKind.contacts);
    });
  });

  group('parseGoogleCallback — URIs ignorées', () {
    test('URI sans rapport', () {
      expect(parseGoogleCallback(Uri.parse('omnisms://settings/theme')), isNull);
    });

    test('URI http(s) quelconque', () {
      expect(
        parseGoogleCallback(Uri.parse('https://omnisms.app/dashboard')),
        isNull,
      );
    });

    test('URI vide', () {
      expect(parseGoogleCallback(Uri.parse('')), isNull);
    });
  });

  group('GoogleAuthMessages — messages utilisateur', () {
    test('refus Google', () {
      expect(
        GoogleAuthMessages.forCallbackError('GOOGLE_OAUTH_DENIED'),
        'Connexion Google annulée.',
      );
    });

    test('code d\'échange expiré ou déjà utilisé', () {
      expect(
        GoogleAuthMessages.forExchangeError(401, 'GOOGLE_EXCHANGE_CODE_INVALID'),
        'La session Google a expiré. Réessayez.',
      );
    });

    test('Google non configuré (503)', () {
      expect(
        GoogleAuthMessages.forExchangeError(503, 'GOOGLE_NOT_CONFIGURED'),
        GoogleAuthMessages.notConfigured,
      );
      expect(
        GoogleAuthMessages.forExchangeError(503, ''),
        GoogleAuthMessages.notConfigured,
      );
    });

    test('conflit d\'identité', () {
      expect(
        GoogleAuthMessages.forCallbackError('GOOGLE_IDENTITY_CONFLICT'),
        GoogleAuthMessages.identityConflict,
      );
    });

    test('erreur inconnue → message générique (pas de fuite technique)', () {
      final message = GoogleAuthMessages.forCallbackError('ERROR_INTERNE_XYZ');

      expect(message, GoogleAuthMessages.exchangeFailed);
      expect(message.contains('ERROR_INTERNE_XYZ'), isFalse);
      expect(message.contains('token'), isFalse);
    });
  });

  group('GoogleContactsMessages', () {
    test('codes backend mappés', () {
      expect(
        GoogleContactsMessages.forCode('GOOGLE_CONTACTS_AUTH_REQUIRED'),
        GoogleContactsMessages.authorizationRequired,
      );
      expect(
        GoogleContactsMessages.forCode('GOOGLE_TOKEN_EXPIRED'),
        GoogleContactsMessages.authorizationRequired,
      );
      expect(
        GoogleContactsMessages.forCode('GOOGLE_PEOPLE_API_UNAVAILABLE'),
        GoogleContactsMessages.serviceUnavailable,
      );
      expect(
        GoogleContactsMessages.forCode('NO_TOKEN'),
        GoogleContactsMessages.notConnected,
      );
      expect(
        GoogleContactsMessages.forCode('GOOGLE_OAUTH_DENIED'),
        GoogleContactsMessages.denied,
      );
    });

    test('code inconnu → message d\'échec générique', () {
      expect(
        GoogleContactsMessages.forCode('WHATEVER'),
        GoogleContactsMessages.importFailed,
      );
    });

    test('résumé des compteurs renvoyés par le backend', () {
      final summary = GoogleContactsMessages.summary({
        'success': true,
        'empty': false,
        'totalGoogleContacts': 40,
        'totalPhoneNumbers': 33,
        'imported': 25,
        'updated': 4,
        'omnismsMatches': 12,
        'external': 21,
        'skippedExisting': 4,
        'invalidNumbers': 2,
        'duplicateNumbers': 1,
        'truncated': false,
      });

      expect(summary, '25 importés, 4 mis à jour, 12 sur OmniSMS');
    });

    test('carnet Google vide', () {
      expect(
        GoogleContactsMessages.summary({'success': true, 'empty': true}),
        'Aucun nouveau contact à importer.',
      );
    });

    test('rien de neuf (tout déjà présent)', () {
      expect(
        GoogleContactsMessages.summary({
          'success': true,
          'empty': false,
          'imported': 0,
          'updated': 0,
          'omnismsMatches': 3,
          'skippedExisting': 12,
        }),
        'Aucun nouveau contact à importer.',
      );
    });

    test('singulier/pluriel', () {
      expect(
        GoogleContactsMessages.summary({'imported': 1, 'updated': 0}),
        '1 importé',
      );
    });
  });
}
