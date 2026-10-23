// ─────────────────────────────────────────────────────────────────────────
// Statut des messages — l'affichage doit refléter le statut serveur.
//
// Règle : un message n'est jamais présenté comme remis sans confirmation du
// backend. Envoi en cours, échec, remis et lu sont des états distincts.
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/models/message_model.dart';
import 'package:omnisms/widgets/chat/modern_message_bubble.dart';

Widget _bulle(MessageStatus? status) => MaterialApp(
      home: Scaffold(
        body: ModernMessageBubble(
          message: 'Bonjour',
          isMe: true,
          timestamp: DateTime(2026, 10, 23, 10),
          status: status,
        ),
      ),
    );

void main() {
  testWidgets('envoi en cours : une horloge, jamais une coche', (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.sending));
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.byIcon(Icons.done), findsNothing);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('échec d\'envoi : icône d\'erreur, jamais « remis »', (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.failed));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('envoyé (non confirmé) : une seule coche grise', (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.sent));
    expect(find.byIcon(Icons.done), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
  });

  testWidgets('remis : double coche grise', (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.delivered));
    final icone = tester.widget<Icon>(find.byIcon(Icons.done_all));
    expect(icone.color, Colors.grey);
  });

  testWidgets('lu : double coche bleue', (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.read));
    final icone = tester.widget<Icon>(find.byIcon(Icons.done_all));
    expect(icone.color, const Color(0xFF0084FF));
  });

  testWidgets('statut absent : repli sur isRead (comportement historique)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModernMessageBubble(
          message: 'Bonjour',
          isMe: true,
          timestamp: DateTime(2026, 10, 23, 10),
          isRead: true,
        ),
      ),
    ));
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('un message reçu n\'affiche aucun indicateur d\'envoi',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ModernMessageBubble(
          message: 'Salut',
          isMe: false,
          timestamp: DateTime(2026, 10, 23, 10),
          status: MessageStatus.read,
        ),
      ),
    ));
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.byIcon(Icons.done), findsNothing);
  });

  test('le modèle n\'invente pas un statut « remis »', () {
    // Statut absent du JSON → « envoyé », jamais « remis » ni « lu ».
    final message = MessageModel.fromJson(<String, dynamic>{
      'id': 'm-1',
      'content': 'Coucou',
    });
    expect(message.status, MessageStatus.sent);
  });
}
