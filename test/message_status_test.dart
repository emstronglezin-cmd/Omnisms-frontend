// ─────────────────────────────────────────────────────────────────────────
// Statut des messages — l'affichage doit refléter le statut serveur.
//
// Règle : un message n'est jamais présenté comme remis sans confirmation du
// backend. Envoi en cours, échec, remis et lu sont des états distincts.
//
// Mise à jour lors de la refonte des bulles (design system Omni) : les
// icônes Material « arrondies » remplacent les anciennes, et les couleurs
// viennent du thème au lieu d'être codées en dur (#0084FF, Colors.grey).
// Les assertions portent donc sur la SÉMANTIQUE — « remis » et « lu » doivent
// rester visuellement distincts — et non sur une valeur de couleur fixe.
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/models/message_model.dart';
import 'package:omnisms/theme/omni_theme.dart';
import 'package:omnisms/widgets/chat/modern_message_bubble.dart';

Widget _bulle(
  MessageStatus? status, {
  bool isMe = true,
  ThemeData? theme,
}) =>
    MaterialApp(
      theme: theme ?? OmniTheme.sombre(),
      home: Scaffold(
        body: ModernMessageBubble(
          message: 'Bonjour',
          isMe: isMe,
          timestamp: DateTime(2026, 10, 23, 10),
          status: status,
        ),
      ),
    );

/// Couleur de l'icône de statut affichée dans la bulle.
Color _couleurStatut(WidgetTester tester, IconData icone) {
  final widget = tester.widget<Icon>(find.byIcon(icone));
  return widget.color!;
}

void main() {
  testWidgets('envoi en cours : une horloge, jamais une coche', (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.sending));
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byIcon(Icons.done_rounded), findsNothing);
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
  });

  testWidgets('échec d\'envoi : icône d\'erreur, jamais « remis »',
      (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.failed));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
  });

  testWidgets('envoyé (non confirmé) : une seule coche', (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.sent));
    expect(find.byIcon(Icons.done_rounded), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
  });

  testWidgets('remis : double coche', (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.delivered));
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
  });

  testWidgets('lu : double coche, visuellement distinct de « remis »',
      (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.read));
    final couleurLu = _couleurStatut(tester, Icons.done_all_rounded);

    await tester.pumpWidget(_bulle(MessageStatus.delivered));
    final couleurRemis = _couleurStatut(tester, Icons.done_all_rounded);

    expect(
      couleurLu,
      isNot(equals(couleurRemis)),
      reason: '« lu » et « remis » ne doivent pas se confondre',
    );
  });

  testWidgets('les statuts restent lisibles en thème clair comme en sombre',
      (tester) async {
    final erreurs = <FlutterErrorDetails>[];
    final precedente = FlutterError.onError;
    FlutterError.onError = erreurs.add;

    for (final theme in <ThemeData>[OmniTheme.clair(), OmniTheme.sombre()]) {
      for (final statut in MessageStatus.values) {
        await tester.pumpWidget(_bulle(statut, theme: theme));
        expect(find.text('Bonjour'), findsOneWidget);
      }
    }

    FlutterError.onError = precedente;
    expect(erreurs, isEmpty);
  });

  testWidgets('statut absent : repli sur isRead (comportement historique)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: OmniTheme.sombre(),
      home: Scaffold(
        body: ModernMessageBubble(
          message: 'Bonjour',
          isMe: true,
          timestamp: DateTime(2026, 10, 23, 10),
          isRead: true,
        ),
      ),
    ));
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
  });

  testWidgets('un message reçu n\'affiche aucun indicateur d\'envoi',
      (tester) async {
    await tester.pumpWidget(_bulle(MessageStatus.read, isMe: false));
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    expect(find.byIcon(Icons.done_rounded), findsNothing);
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);
  });

  testWidgets('dans un groupe, le nom de l\'expéditeur est affiché',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: OmniTheme.sombre(),
      home: Scaffold(
        body: ModernMessageBubble(
          message: 'Salut tout le monde',
          isMe: false,
          timestamp: DateTime(2026, 10, 23, 10),
          senderName: 'Alice Dupont',
        ),
      ),
    ));
    expect(find.text('Alice Dupont'), findsOneWidget);
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
