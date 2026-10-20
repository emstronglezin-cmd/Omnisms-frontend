import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnisms/config/api_config.dart';
import 'package:omnisms/services/google_oauth_flow.dart';

/// Contrat backend vérifié le 2026-10-20 (repo public Omnisms-backend,
/// `routes/auth.google.js` + `services/googleOAuth.js`) :
///
///   GET /api/auth/google
///     → 302 Google, redirect_uri = …/api/auth/google/callback
///   GET /api/auth/google/callback?state=…&code=…
///     → 302 vers la cible du flux :
///         • variante « app » (défaut)  → GOOGLE_FLUTTER_REDIRECT_URI
///         • variante « web » (?target=web) → GOOGLE_FLUTTER_REDIRECT_URI_WEB
///
/// Sondé en production (retour `error=access_denied`, sans consentement) :
///   • variante app → https://omnisms-frontend-drab.vercel.app/?error=…
///   • variante web → https://omnisms-frontend-drab.vercel.app
///                    /auth/google/callback?error=…
///
/// Autrement dit : aujourd'hui la variante « app » ramène l'utilisateur sur la
/// **PWA à la racine**, pas sur `omnisms://…`. L'APK doit donc reconnaître ce
/// retour (Android App Links) sans jamais détourner un lien étranger.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Callback sur schéma personnalisé omnisms:// (deep link)', () {
    test('login : code reconnu même sans flux déclaré', () {
      final cb = parseGoogleCallback(
        Uri.parse('omnisms://auth/google/callback?code=abc'),
      );
      expect(cb?.kind, GoogleCallbackKind.login);
      expect(cb?.code, 'abc');
    });

    test('contacts : authorized=1 reconnu', () {
      final cb = parseGoogleCallback(
        Uri.parse('omnisms://auth/google/contacts/callback?authorized=1'),
      );
      expect(cb?.kind, GoogleCallbackKind.contacts);
      expect(cb?.authorized, isTrue);
    });
  });

  group('Callback HTTPS (App Links) — chemin canonique', () {
    test('/auth/google/callback?code=… est reconnu', () {
      final cb = parseGoogleCallback(Uri.parse(
        'https://omnisms-frontend-drab.vercel.app'
        '/auth/google/callback?code=xyz',
      ));
      expect(cb?.kind, GoogleCallbackKind.login);
      expect(cb?.code, 'xyz');
    });

    test('/auth/google/contacts/callback n\'est pas confondu avec login', () {
      final cb = parseGoogleCallback(Uri.parse(
        'https://omnisms-frontend-drab.vercel.app'
        '/auth/google/contacts/callback?authorized=1',
      ));
      expect(cb?.kind, GoogleCallbackKind.contacts);
    });
  });

  group('Retour « app » à la racine de la PWA (configuration actuelle)', () {
    final rootWithCode = Uri.parse(
      'https://omnisms-frontend-drab.vercel.app/?code=ONE_TIME_CODE',
    );

    test('ignoré quand aucun flux Google n\'est en cours', () {
      // Aucun navigateur ouvert par l'app → aucun lien ne doit être détourné,
      // même porteur d'un paramètre `code`.
      expect(parseGoogleCallback(rootWithCode), isNull);
    });

    test('reconnu quand un flux login est en cours', () {
      final cb = parseGoogleCallback(
        rootWithCode,
        expect: GoogleCallbackKind.login,
      );
      expect(cb, isNotNull);
      expect(cb!.kind, GoogleCallbackKind.login);
      expect(cb.code, 'ONE_TIME_CODE');
      expect(cb.isSuccess, isTrue);
    });

    test('reconnu quand un flux contacts est en cours', () {
      final cb = parseGoogleCallback(
        Uri.parse('https://omnisms-frontend-drab.vercel.app/?authorized=1'),
        expect: GoogleCallbackKind.contacts,
      );
      expect(cb?.kind, GoogleCallbackKind.contacts);
      expect(cb?.authorized, isTrue);
    });

    test('une erreur explicite est propagée (refus de consentement)', () {
      final cb = parseGoogleCallback(
        Uri.parse(
          'https://omnisms-frontend-drab.vercel.app/'
          '?error=GOOGLE_OAUTH_DENIED',
        ),
        expect: GoogleCallbackKind.login,
      );
      expect(cb?.kind, GoogleCallbackKind.login);
      expect(cb?.isDenied, isTrue);
      expect(cb?.isSuccess, isFalse);
    });

    test('un flux login ne consomme pas un retour contacts', () {
      final cb = parseGoogleCallback(
        Uri.parse('https://omnisms-frontend-drab.vercel.app/?authorized=1'),
        expect: GoogleCallbackKind.login,
      );
      expect(cb, isNull);
    });
  });

  group('Sécurité des hôtes', () {
    test('un hôte non autorisé n\'est jamais détourné', () {
      expect(
        parseGoogleCallback(
          Uri.parse('https://evil.example.com/?code=stolen'),
          expect: GoogleCallbackKind.login,
        ),
        isNull,
      );
    });

    test('un lien sans charge utile OAuth est ignoré', () {
      expect(
        parseGoogleCallback(
          Uri.parse('https://omnisms-frontend-drab.vercel.app/'),
          expect: GoogleCallbackKind.login,
        ),
        isNull,
      );
      expect(
        parseGoogleCallback(
          Uri.parse('https://omnisms-frontend-drab.vercel.app/settings'),
          expect: GoogleCallbackKind.contacts,
        ),
        isNull,
      );
    });

    test('ApiConfig.isGoogleCallbackHost ignore la casse et le port', () {
      expect(ApiConfig.isGoogleCallbackHost('omnisms.vercel.app'), isTrue);
      expect(ApiConfig.isGoogleCallbackHost('OMNISMS.Vercel.app'), isTrue);
      expect(ApiConfig.isGoogleCallbackHost('omnisms.vercel.app:443'), isTrue);
      expect(ApiConfig.isGoogleCallbackHost('not-omnisms.vercel.app'), isFalse);
      expect(ApiConfig.isGoogleCallbackHost(null), isFalse);
      expect(ApiConfig.isGoogleCallbackHost(''), isFalse);
    });
  });

  group('Anti-rejeu du code d\'échange', () {
    test('un même retour livré deux fois n\'est traité qu\'une fois',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final flow = GoogleOAuthFlow.instance;
      await flow.start();
      flow.clearPending();

      final uri = Uri.parse('omnisms://auth/google/callback?code=SAME_CODE');

      // Le backend n'accepte un code qu'une seule fois : le second passage
      // (deep link + App Link, ou reprise de l'application) doit être ignoré.
      flow.handleIncomingUri(uri);
      flow.handleIncomingUri(uri);

      final first = await flow.consumeBuffered(
        GoogleCallbackKind.login,
        wait: Duration.zero,
      );
      expect(first?.code, 'SAME_CODE');

      final second = await flow.consumeBuffered(
        GoogleCallbackKind.login,
        wait: Duration.zero,
      );
      expect(second, isNull);
    });
  });
}
