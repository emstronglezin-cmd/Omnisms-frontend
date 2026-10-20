import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/models/message_model.dart';
import 'package:omnisms/services/messaging_service.dart';

/// Le routage (interne OmniSMS vs SMS) est décidé **côté backend**
/// (`services/messageRouter.js`) : interne seulement si le destinataire a une
/// session Socket.IO active. Le frontend ne décide rien : il affiche la
/// décision (`message.channel`, `route`) sans jamais l'inventer.
void main() {
  group('Canal d\'un message (interne vs SMS)', () {
    test('channel "app" → message interne', () {
      final message = MessageModel.fromJson(<String, dynamic>{
        'id': 'm1',
        'conversationId': 'c1',
        'senderId': 'u1',
        'content': 'coucou',
        'type': 'text',
        'channel': 'app',
        'status': 'sent',
      });

      expect(message.isInternal, isTrue);
      expect(message.isSms, isFalse);
    });

    test('channel "sms" → message passé par le réseau SMS', () {
      final message = MessageModel.fromJson(<String, dynamic>{
        'id': 'm2',
        'conversationId': 'c1',
        'senderId': 'u1',
        'content': 'coucou',
        'type': 'text',
        'channel': 'sms',
        'status': 'sent',
      });

      expect(message.isSms, isTrue);
      expect(message.isInternal, isFalse);
    });

    test('route "INFOBIP" (réponse d\'envoi) est comprise comme un SMS', () {
      final message = MessageModel.fromJson(<String, dynamic>{
        'id': 'm3',
        'conversationId': 'c1',
        'senderId': 'u1',
        'content': 'coucou',
        'type': 'text',
        'route': 'INFOBIP',
        'status': 'sent',
      });

      expect(message.isSms, isTrue);
    });

    test('route "OMNISMS" est comprise comme un message interne', () {
      final message = MessageModel.fromJson(<String, dynamic>{
        'id': 'm4',
        'conversationId': 'c1',
        'senderId': 'u1',
        'content': 'coucou',
        'type': 'text',
        'route': 'OMNISMS',
        'status': 'sent',
      });

      expect(message.isInternal, isTrue);
    });

    test('canal absent → ni interne ni SMS (aucun état inventé)', () {
      final message = MessageModel.fromJson(<String, dynamic>{
        'id': 'm5',
        'conversationId': 'c1',
        'senderId': 'u1',
        'content': 'coucou',
        'type': 'text',
        'status': 'sent',
      });

      expect(message.channel, isNull);
      expect(message.isSms, isFalse);
      expect(message.isInternal, isFalse);
    });

    test('canal inattendu → ignoré plutôt que deviné', () {
      final message = MessageModel.fromJson(<String, dynamic>{
        'id': 'm6',
        'conversationId': 'c1',
        'senderId': 'u1',
        'content': 'coucou',
        'type': 'text',
        'channel': 'telepathy',
        'status': 'sent',
      });

      expect(message.channel, isNull);
    });
  });

  group('Résultat d\'envoi', () {
    test('route OMNISMS → pas de bascule SMS', () {
      final result = MessageSendResult(
        route: 'OMNISMS',
        smsSent: false,
        message: MessageModel.fromJson(<String, dynamic>{
          'id': 'm7',
          'conversationId': 'c1',
          'senderId': 'u1',
          'content': 'x',
          'type': 'text',
          'channel': 'app',
          'status': 'sent',
        }),
      );

      expect(result.isSuccess, isTrue);
      expect(result.isSmsFallback, isFalse);
    });

    test('route INFOBIP → bascule SMS signalée', () {
      final result = MessageSendResult(
        route: 'INFOBIP',
        smsSent: true,
        statusCode: 201,
      );

      expect(result.isSuccess, isFalse, reason: 'pas de message confirmé ici');
      expect(result.isSmsFallback, isTrue);
    });

    test('échec réseau → renvoyable, aucune conclusion sur le canal', () {
      const result = MessageSendResult(networkError: true);

      expect(result.isSuccess, isFalse);
      expect(result.isSmsFallback, isFalse);
      expect(result.networkError, isTrue);
    });
  });

  group('Asset du logo officiel Google', () {
    test('le SVG embarque les 4 couleurs officielles et 4 tracés', () {
      final file = File('assets/images/google_g_logo.svg');
      expect(file.existsSync(), isTrue,
          reason: 'l\'asset du logo officiel est requis');

      final content = file.readAsStringSync();
      for (final color in const [
        '#4285F4', // bleu
        '#34A853', // vert
        '#FBBC05', // jaune
        '#EA4335', // rouge
      ]) {
        expect(content, contains(color));
      }
      expect('<path'.allMatches(content).length, 4);
      expect(content, contains('viewBox="0 0 48 48"'));
    });

    test('aucun bouton ne dessine plus un « G » bleu approximatif', () {
      final button = File('lib/widgets/auth/google_sign_in_button.dart');
      final source = button.readAsStringSync();
      expect(source, contains('assets/images/google_g_logo.svg'));
      expect(source, isNot(contains("Text(\n                      'G'")));
      expect(source, isNot(contains("child: const Text(\n                      'G'")));
    });
  });
}
