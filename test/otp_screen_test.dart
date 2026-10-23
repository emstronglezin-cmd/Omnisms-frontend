import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnisms/models/models.dart';
import 'package:omnisms/providers/auth_provider.dart';
import 'package:omnisms/providers/contacts_provider_v2.dart';
import 'package:omnisms/providers/groups_provider.dart';
import 'package:omnisms/providers/messaging_provider.dart';
import 'package:omnisms/screens/auth/otp_verification_screen.dart';
import 'package:omnisms/services/otp_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_service.dart';

http.Response _json(int status, Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Construit un provider déjà en attente de vérification (comme après une
/// inscription refusée par le serveur tant que le numéro n'est pas vérifié).
Future<AuthProvider> _pendingProvider(
  WidgetTester tester, {
  required MockClient client,
}) async {
  final auth = FakeAuthService();
  await auth.clearPendingVerification();
  auth.nextRegisterResult = <String, dynamic>{
    'success': true,
    'requiresOtp': true,
    'verification': PendingVerification(
      phone: '+22670123456',
      userId: 'uid-1',
      origin: VerificationOrigin.signup,
    ),
  };

  final provider = AuthProvider(
    authService: auth,
    otpService: OtpService(client: client),
  );
  // Laisse _checkLoginStatus se terminer.
  await tester.pump();

  await provider.register(
    name: 'Awa',
    password: 'motdepasse',
    username: 'awa',
    phone: '+22670123456',
  );
  await tester.pump();
  return provider;
}

/// L'écran OTP pousse le tableau de bord après vérification : on fournit
/// aussi la messagerie pour que l'écran suivant puisse se construire
/// (son constructeur ne déclenche aucun appel réseau sans jeton en mémoire).
Widget _app(AuthProvider provider) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: provider),
        ChangeNotifierProvider<MessagingProvider>(
            create: (_) => MessagingProvider()),
        ChangeNotifierProvider<ContactsProviderV2>(
            create: (_) => ContactsProviderV2()),
        ChangeNotifierProvider<GroupsProvider>(create: (_) => GroupsProvider()),
      ],
      child: const MaterialApp(home: OtpVerificationScreen()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets("affiche le numéro et envoie le code à l'ouverture",
      (tester) async {
    var sendCalls = 0;
    final provider = await _pendingProvider(
      tester,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/send-otp')) {
          sendCalls++;
          return _json(200, {'success': true, 'message': 'Code envoyé.'});
        }
        return _json(200, {'success': true, 'token': 'jwt'});
      }),
    );

    await tester.pumpWidget(_app(provider));
    await tester.pump();          // envoi initial programmé
    await tester.pump();          // résolution du futur

    expect(sendCalls, 1, reason: "un seul envoi à l'ouverture de l'écran");
    expect(find.textContaining('+22670123456'), findsOneWidget);
    expect(find.text('Vérifier'), findsOneWidget);
  });

  testWidgets('code erroné : message du serveur affiché, session fermée',
      (tester) async {
    var verifyCalls = 0;
    final provider = await _pendingProvider(
      tester,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/verify-otp')) {
          verifyCalls++;
          return _json(400, {
            'success': false,
            'error': 'Code OTP incorrect.',
            'code': 'OTP_INVALID',
            'triesRemaining': 2,
          });
        }
        return _json(200, {'success': true, 'message': 'Code envoyé.'});
      }),
    );

    await tester.pumpWidget(_app(provider));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.pump();

    expect(verifyCalls, 1);
    expect(find.textContaining('Code incorrect'), findsOneWidget);
    expect(provider.isLoggedIn, isFalse);
    expect(provider.needsPhoneVerification, isTrue);
  });

  testWidgets('service indisponible : message clair, aucune session',
      (tester) async {
    final provider = await _pendingProvider(
      tester,
      client: MockClient((request) async => _json(404, {
            'error': 'Route not found.',
            'code': 'NOT_FOUND',
          })),
    );

    await tester.pumpWidget(_app(provider));
    await tester.pump();
    await tester.pump();

    // L'envoi initial a échoué → message d'indisponibilité.
    expect(find.textContaining('indisponible'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump();

    expect(provider.isLoggedIn, isFalse);
    expect(provider.otpFailure, OtpFailure.serviceUnavailable);
  });

  testWidgets('renvoi désactivé pendant le délai serveur', (tester) async {
    final provider = await _pendingProvider(
      tester,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/send-otp')) {
          return _json(200, {'success': true, 'message': 'Code envoyé.'});
        }
        return _json(200, {'success': true, 'token': 'jwt'});
      }),
    );

    await tester.pumpWidget(_app(provider));
    await tester.pump();
    await tester.pump();

    // Le compte à rebours de 60 s a démarré : le bouton de renvoi est
    // désactivé et affiche le temps restant.
    final resend = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Renvoyer un code dans 60 s'),
    );
    expect(resend.onPressed, isNull);
    expect(find.text('Renvoyer un code'), findsNothing);
  });

  testWidgets('« Modifier le numéro » abandonne la vérification',
      (tester) async {
    final provider = await _pendingProvider(
      tester,
      client: MockClient((request) async =>
          _json(200, {'success': true, 'message': 'Code envoyé.'})),
    );

    await tester.pumpWidget(_app(provider));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Modifier le numéro'));
    await tester.pumpAndSettle();          // dialogue de confirmation

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(provider.needsPhoneVerification, isFalse);
    expect(provider.isLoggedIn, isFalse);
  });
}
