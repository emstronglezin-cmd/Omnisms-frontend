import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnisms/config/api_config.dart';
import 'package:omnisms/models/models.dart';
import 'package:omnisms/providers/auth_provider.dart';
import 'package:omnisms/services/auth_service.dart';
import 'package:omnisms/services/otp_service.dart';
import 'helpers/fake_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────
// Faux client HTTP : reproduit les réponses RÉELLES du backend
// (routes/otp.js + services/otpService.js).
// ─────────────────────────────────────────────────────────────────────────
http.Response _json(int status, Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

class _Recorder {
  final List<String> bodies = <String>[];
  int calls = 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhoneFormatter — normalisation avant envoi', () {
    test('numéro déjà international : mise en forme retirée', () {
      expect(PhoneFormatter.normalize('+226 70 12 34 56'), '+22670123456');
    });

    test('préfixe 00 transformé en +', () {
      expect(PhoneFormatter.normalize('0022670123456'), '+22670123456');
    });

    test('numéro national : indicatif Burkina Faso par défaut', () {
      expect(PhoneFormatter.normalize('70123456'), '+22670123456');
    });

    test('parenthèses et tirets ignorés', () {
      expect(PhoneFormatter.normalize('(+226) 70-12-34-56'), '+22670123456');
    });

    test('validité E.164', () {
      expect(PhoneFormatter.isValid('+22670123456'), isTrue);
      expect(PhoneFormatter.isValid('+226'), isFalse);
      expect(PhoneFormatter.isValid('abc'), isFalse);
    });

    test('masquage pour affichage', () {
      expect(PhoneFormatter.mask('+22670123456'), '+226701•••56');
    });
  });

  group('OtpService — envoi du code', () {
    test('succès : message du serveur et aucun stockage du code', () async {
      final rec = _Recorder();
      final service = OtpService(
        client: MockClient((request) async {
          rec.calls++;
          rec.bodies.add(request.body);
          return _json(200, {
            'success': true,
            'message': 'Code envoyé au +22670123456. Valable 10 minutes.',
            'phone': '+22670123456',
          });
        }),
      );

      final result = await service.sendCode(phone: '+226 70 12 34 56');

      expect(result.ok, isTrue);
      expect(result.failure, isNull);
      expect(rec.calls, 1);
      // Le numéro envoyé est bien normalisé.
      expect(jsonDecode(rec.bodies.single)['phone'], '+22670123456');
      service.dispose();
    });

    test('numéro invalide : aucun appel réseau', () async {
      final rec = _Recorder();
      final service = OtpService(
        client: MockClient((request) async {
          rec.calls++;
          return _json(200, {'success': true});
        }),
      );

      final result = await service.sendCode(phone: 'pas-un-numero');

      expect(result.ok, isFalse);
      expect(result.failure, OtpFailure.validation);
      expect(rec.calls, 0,
          reason: 'un numéro invalide ne doit jamais partir sur le réseau');
      service.dispose();
    });

    test('renvoi trop rapproché : OTP_COOLDOWN avec durée serveur', () async {
      final service = OtpService(
        client: MockClient((request) async => _json(429, {
              'success': false,
              'error': 'Attendez 42 secondes avant de renvoyer un OTP.',
              'code': 'OTP_COOLDOWN',
              'cooldown': 42,
            })),
      );

      final result = await service.sendCode(phone: '+22670123456');

      expect(result.ok, isFalse);
      expect(result.failure, OtpFailure.cooldown);
      expect(result.cooldownSeconds, 42);
      expect(result.message, contains('42 s'));
      service.dispose();
    });

    test('endpoint absent (404 hors OTP_NOT_FOUND) = service indisponible',
        () async {
      final service = OtpService(
        client: MockClient((request) async => _json(404, {
              'error': 'Route not found.',
              'code': 'NOT_FOUND',
              'path': '/api/auth/send-otp',
            })),
      );

      final result = await service.sendCode(phone: '+22670123456');

      expect(result.ok, isFalse);
      expect(result.failure, OtpFailure.serviceUnavailable);
      expect(result.message, contains('indisponible'));
      service.dispose();
    });

    test('erreur réseau mappée proprement', () async {
      final service = OtpService(
        client: MockClient((request) async => throw http.ClientException('Failed host lookup')),
      );

      final result = await service.sendCode(phone: '+22670123456');

      expect(result.failure, OtpFailure.network);
      expect(result.message, contains('connexion internet'));
      service.dispose();
    });

    test('double envoi concurrent refusé', () async {
      var calls = 0;
      final service = OtpService(
        client: MockClient((request) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return _json(200, {'success': true});
        }),
      );

      final first = service.sendCode(phone: '+22670123456');
      final second = service.sendCode(phone: '+22670123456');
      final results = await Future.wait([first, second]);

      expect(results.first.ok, isTrue);
      expect(results.last.ok, isFalse,
          reason: 'la seconde requête ne doit pas partir');
      expect(calls, 1);
      service.dispose();
    });
  });

  group('OtpService — vérification du code', () {
    test('succès : jeton ET utilisateur renvoyés par le serveur', () async {
      final service = OtpService(
        client: MockClient((request) async => _json(200, {
              'success': true,
              'message': 'Numéro vérifié.',
              'token': 'jwt.apres.verification',
              'phoneVerified': true,
              'user': {
                'id': 'uid-1',
                'name': 'Awa',
                'phone': '+22670123456',
                'phoneVerified': true,
              },
            })),
      );

      final result = await service.verifyCode(
        phone: '+22670123456',
        code: '123456',
      );

      expect(result.ok, isTrue);
      expect(result.token, 'jwt.apres.verification');
      expect(result.user?.id, 'uid-1');
      expect(result.user?.phoneVerified, isTrue);
      service.dispose();
    });

    test('200 sans jeton : échec fermé (pas de session)', () async {
      final service = OtpService(
        client: MockClient((request) async => _json(200, {
              'success': true,
              'message': 'ok',
              // pas de token
            })),
      );

      final result = await service.verifyCode(
        phone: '+22670123456',
        code: '123456',
      );

      expect(result.ok, isFalse,
          reason: 'sans jeton serveur, la vérification n\'est pas acquise');
      expect(result.token, isNull);
      service.dispose();
    });

    test('code incorrect : essais restants affichés', () async {
      final service = OtpService(
        client: MockClient((request) async => _json(400, {
              'success': false,
              'error': 'Code OTP incorrect.',
              'code': 'OTP_INVALID',
              'triesRemaining': 2,
            })),
      );

      final result = await service.verifyCode(
        phone: '+22670123456',
        code: '000000',
      );

      expect(result.ok, isFalse);
      expect(result.failure, OtpFailure.invalidCode);
      expect(result.triesRemaining, 2);
      expect(result.message, contains('2 essais'));
      service.dispose();
    });

    test('code expiré (410)', () async {
      final service = OtpService(
        client: MockClient((request) async => _json(410, {
              'success': false,
              'error': 'Code OTP expiré. Demandez un nouveau code.',
              'code': 'OTP_EXPIRED',
            })),
      );

      final result = await service.verifyCode(
        phone: '+22670123456',
        code: '123456',
      );

      expect(result.failure, OtpFailure.expired);
      expect(result.message, contains('expiré'));
      service.dispose();
    });

    test('trop de tentatives (429 OTP_MAX_TRIES)', () async {
      final service = OtpService(
        client: MockClient((request) async => _json(429, {
              'success': false,
              'error': 'Trop de tentatives.',
              'code': 'OTP_MAX_TRIES',
            })),
      );

      final result = await service.verifyCode(
        phone: '+22670123456',
        code: '123456',
      );

      expect(result.failure, OtpFailure.tooManyAttempts);
      service.dispose();
    });

    test('aucun code en attente (404 OTP_NOT_FOUND)', () async {
      final service = OtpService(
        client: MockClient((request) async => _json(404, {
              'success': false,
              'error': 'Aucun OTP en attente pour ce numéro.',
              'code': 'OTP_NOT_FOUND',
            })),
      );

      final result = await service.verifyCode(
        phone: '+22670123456',
        code: '123456',
      );

      expect(result.failure, OtpFailure.noPendingCode);
      service.dispose();
    });

    test('route non montée (404 générique) = service indisponible', () async {
      final service = OtpService(
        client: MockClient((request) async => _json(404, {
              'error': 'Route not found.',
              'code': 'NOT_FOUND',
            })),
      );

      final result = await service.verifyCode(
        phone: '+22670123456',
        code: '123456',
      );

      expect(result.failure, OtpFailure.serviceUnavailable);
      service.dispose();
    });

    test('erreur serveur 500', () async {
      final service = OtpService(
        client: MockClient((request) async => _json(500, {
              'error': 'Erreur serveur.',
              'code': 'SERVER_ERROR',
            })),
      );

      final result = await service.verifyCode(
        phone: '+22670123456',
        code: '123456',
      );

      expect(result.failure, OtpFailure.server);
      service.dispose();
    });

    test('code malformé : refusé localement, aucun appel réseau', () async {
      var calls = 0;
      final service = OtpService(
        client: MockClient((request) async {
          calls++;
          return _json(200, {'success': true});
        }),
      );

      final result = await service.verifyCode(
        phone: '+22670123456',
        code: '12ab',
      );

      expect(result.ok, isFalse);
      expect(result.failure, OtpFailure.validation);
      expect(calls, 0);
      service.dispose();
    });
  });

  group('AuthService.serverRequiresVerification — décision serveur', () {
    test('requiresOtp: true → vérification exigée', () {
      expect(
        AuthService.serverRequiresVerification(
          {'requiresOtp': true, 'user': {'phone': '+22670123456'}},
          isSignup: true,
        ),
        isTrue,
      );
    });

    test('user.phoneVerified: false → vérification exigée', () {
      expect(
        AuthService.serverRequiresVerification(
          {'token': 'x', 'user': {'phoneVerified': false}},
          isSignup: false,
        ),
        isTrue,
      );
    });

    test('compte déjà vérifié → aucune vérification', () {
      expect(
        AuthService.serverRequiresVerification(
          {'token': 'x', 'user': {'phoneVerified': true}},
          isSignup: false,
        ),
        isFalse,
      );
    });

    test('champ absent → considéré vérifié (règle serveur)', () {
      expect(
        AuthService.serverRequiresVerification(
          {'token': 'x', 'user': {'phone': '+22670123456'}},
          isSignup: false,
        ),
        isFalse,
        reason: 'le backend applique phoneVerified !== false',
      );
    });
  });

  group('AuthProvider — parcours OTP (session jamais ouverte trop tôt)', () {
    late FakeAuthService fakeAuth;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      fakeAuth = FakeAuthService();
      await fakeAuth.clearPendingVerification();
    });

    test('inscription exigeant l\'OTP : aucune session ouverte', () async {
      fakeAuth.nextRegisterResult = <String, dynamic>{
        'success': true,
        'requiresOtp': true,
        'verification': PendingVerification(phone: '+22670123456'),
      };

      final provider = AuthProvider(authService: fakeAuth);
      await pumpEventQueue();

      final ok = await provider.register(
        name: 'Awa',
        password: 'motdepasse',
        username: 'awa',
        phone: '+22670123456',
      );

      expect(ok, isTrue);
      expect(provider.isLoggedIn, isFalse,
          reason: 'la session doit rester fermée avant vérification');
      expect(provider.needsPhoneVerification, isTrue);
      expect(provider.pendingVerification?.phone, '+22670123456');
      expect(fakeAuth.savedToken, isNull,
          reason: 'aucun jeton d\'accès ne doit être enregistré');
    });

    test('compte déjà vérifié : connexion directe, aucun OTP', () async {
      fakeAuth.nextLoginResult = <String, dynamic>{
        'success': true,
        'requiresOtp': false,
        'token': 'jwt.ok',
        'user': UserModel(id: 'u1', phone: '+22670123456', phoneVerified: true),
      };

      final provider = AuthProvider(authService: fakeAuth);
      await pumpEventQueue();

      final ok = await provider.login(
        identifier: '+22670123456',
        password: 'motdepasse',
      );

      expect(ok, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.needsPhoneVerification, isFalse);
    });

    test('compte existant non vérifié : reprise du parcours OTP', () async {
      fakeAuth.nextLoginResult = <String, dynamic>{
        'success': true,
        'requiresOtp': true,
        'verification': PendingVerification(
          phone: '+22670123456',
          origin: VerificationOrigin.login,
        ),
      };

      final provider = AuthProvider(authService: fakeAuth);
      await pumpEventQueue();

      await provider.login(identifier: '+22670123456', password: 'mdp');

      expect(provider.needsPhoneVerification, isTrue);
      expect(provider.isLoggedIn, isFalse);
      expect(provider.pendingVerification?.origin, VerificationOrigin.login);
    });

    test('Google — nouveau compte : vérification exigée', () async {
      fakeAuth.nextGoogleResult = <String, dynamic>{
        'success': true,
        'requiresOtp': true,
        'verification': PendingVerification(
          phone: '+22670123456',
          origin: VerificationOrigin.google,
        ),
      };

      final provider = AuthProvider(authService: fakeAuth);
      await pumpEventQueue();

      await provider.loginWithGoogle();

      expect(provider.needsPhoneVerification, isTrue);
      expect(provider.isLoggedIn, isFalse);
      expect(provider.pendingVerification?.origin, VerificationOrigin.google);
    });

    test('Google — compte déjà vérifié : connexion normale, sans OTP',
        () async {
      fakeAuth.nextGoogleResult = <String, dynamic>{
        'success': true,
        'requiresOtp': false,
        'token': 'jwt.google',
        'user': UserModel(id: 'g1', email: 'a@b.c', phoneVerified: true),
      };

      final provider = AuthProvider(authService: fakeAuth);
      await pumpEventQueue();

      final ok = await provider.loginWithGoogle();

      expect(ok, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.needsPhoneVerification, isFalse);
    });

    test('vérification confirmée par le serveur → session ouverte', () async {
      fakeAuth.nextRegisterResult = <String, dynamic>{
        'success': true,
        'requiresOtp': true,
        'verification': PendingVerification(
            phone: '+22670123456', userId: 'uid-1'),
      };

      final provider = AuthProvider(
        authService: fakeAuth,
        otpService: OtpService(
          client: MockClient((request) async => _json(200, {
                'success': true,
                'token': 'jwt.verifie',
                'user': {
                  'id': 'uid-1',
                  'phone': '+22670123456',
                  'phoneVerified': true,
                },
              })),
        ),
      );
      await pumpEventQueue();

      await provider.register(
        name: 'Awa',
        password: 'motdepasse',
        username: 'awa',
        phone: '+22670123456',
      );
      expect(provider.needsPhoneVerification, isTrue);

      final ok = await provider.verifyOtp('123456');

      expect(ok, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.needsPhoneVerification, isFalse);
      expect(fakeAuth.savedToken, 'jwt.verifie');
      expect(await fakeAuth.getPendingVerification(), isNull,
          reason: 'la vérification en attente doit être purgée');
      expect(provider.currentUser?.phoneVerified, isTrue);
    });

    test('vérification refusée → toujours en attente, pas de session',
        () async {
      fakeAuth.nextRegisterResult = <String, dynamic>{
        'success': true,
        'requiresOtp': true,
        'verification': PendingVerification(phone: '+22670123456'),
      };

      final provider = AuthProvider(
        authService: fakeAuth,
        otpService: OtpService(
          client: MockClient((request) async => _json(410, {
                'success': false,
                'error': 'Code OTP expiré.',
                'code': 'OTP_EXPIRED',
              })),
        ),
      );
      await pumpEventQueue();

      await provider.register(
        name: 'Awa',
        password: 'motdepasse',
        username: 'awa',
        phone: '+22670123456',
      );

      final ok = await provider.verifyOtp('123456');

      expect(ok, isFalse);
      expect(provider.isLoggedIn, isFalse);
      expect(provider.needsPhoneVerification, isTrue);
      expect(provider.otpFailure, OtpFailure.expired);
      expect(provider.otpError, contains('expiré'));
      expect(fakeAuth.savedToken, isNull);
    });

    test('service indisponible (endpoints non montés) → message clair',
        () async {
      fakeAuth.nextRegisterResult = <String, dynamic>{
        'success': true,
        'requiresOtp': true,
        'verification': PendingVerification(phone: '+22670123456'),
      };

      final provider = AuthProvider(
        authService: fakeAuth,
        otpService: OtpService(
          client: MockClient((request) async => _json(404, {
                'error': 'Route not found.',
                'code': 'NOT_FOUND',
              })),
        ),
      );
      await pumpEventQueue();

      await provider.register(
        name: 'Awa',
        password: 'motdepasse',
        username: 'awa',
        phone: '+22670123456',
      );

      final resend = await provider.resendOtp();
      expect(resend.failure, OtpFailure.serviceUnavailable);

      final ok = await provider.verifyOtp('123456');
      expect(ok, isFalse);
      expect(provider.otpFailure, OtpFailure.serviceUnavailable);
      expect(provider.isLoggedIn, isFalse,
          reason: 'jamais de session sans confirmation serveur');
    });

    test('double soumission du code refusée', () async {
      fakeAuth.nextRegisterResult = <String, dynamic>{
        'success': true,
        'requiresOtp': true,
        'verification': PendingVerification(phone: '+22670123456'),
      };

      var verifyCalls = 0;
      final provider = AuthProvider(
        authService: fakeAuth,
        otpService: OtpService(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/verify-otp')) verifyCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 60));
            return _json(200, {
              'success': true,
              'token': 'jwt.verifie',
              'user': {'id': 'uid-1', 'phoneVerified': true},
            });
          }),
        ),
      );
      await pumpEventQueue();

      await provider.register(
        name: 'Awa',
        password: 'motdepasse',
        username: 'awa',
        phone: '+22670123456',
      );

      final first = provider.verifyOtp('123456');
      final second = provider.verifyOtp('123456');
      await Future.wait([first, second]);

      expect(verifyCalls, 1,
          reason: 'un seul appel de vérification doit partir');
      expect(provider.isLoggedIn, isTrue);
    });

    test('abandon de la vérification : retour propre, aucune session',
        () async {
      fakeAuth.nextRegisterResult = <String, dynamic>{
        'success': true,
        'requiresOtp': true,
        'verification': PendingVerification(phone: '+22670123456'),
      };

      final provider = AuthProvider(authService: fakeAuth);
      await pumpEventQueue();

      await provider.register(
        name: 'Awa',
        password: 'motdepasse',
        username: 'awa',
        phone: '+22670123456',
      );
      expect(provider.needsPhoneVerification, isTrue);

      await provider.cancelVerification();

      expect(provider.needsPhoneVerification, isFalse);
      expect(provider.isLoggedIn, isFalse);
      expect(await fakeAuth.getPendingVerification(), isNull);
    });

    test('vérification en attente restaurée au démarrage', () async {
      await fakeAuth.seedPendingVerification(
        PendingVerification(phone: '+22670123456', userId: 'uid-9'),
      );

      final provider = AuthProvider(authService: fakeAuth);
      await pumpEventQueue();

      expect(provider.needsPhoneVerification, isTrue,
          reason: 'une vérification interrompue doit être reprise');
      expect(provider.isLoggedIn, isFalse);
    });
  });

  group('Contrat de configuration', () {
    test('endpoints OTP conformes au backend', () {
      expect(ApiConfig.authSendOtpEndpoint, '/api/auth/send-otp');
      expect(ApiConfig.authVerifyOtpEndpoint, '/api/auth/verify-otp');
      expect(ApiConfig.otpCodeLength, 6,
          reason: 'OTP_LENGTH = 6 dans services/otpService.js');
      expect(ApiConfig.otpResendCooldownSeconds, 60,
          reason: 'OTP_COOLDOWN_MS = 60 s');
      expect(ApiConfig.otpValiditySeconds, 600, reason: 'OTP_TTL_MS = 10 min');
    });
  });
}
