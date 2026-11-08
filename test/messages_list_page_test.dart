import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnisms/models/conversation_model.dart';
import 'package:omnisms/providers/messaging_provider.dart';
import 'package:omnisms/screens/messaging/messages_list_page.dart';
import 'package:omnisms/theme/omni_theme.dart';

/// Fournisseur **sans réseau** : `loadConversations()` est neutralisé pour que
/// le test ne dépende jamais du backend. Les conversations sont injectées via
/// `addOrUpdateConversation()`, qui est l'API publique réelle du provider.
class _ProviderHorsLigne extends MessagingProvider {
  @override
  Future<void> loadConversations() async {}
}

ConversationModel _conversation({
  required String id,
  required String nom,
  String? dernierMessage,
  int nonLus = 0,
  DateTime? date,
}) {
  return ConversationModel(
    id: id,
    otherUserId: 'usr-$id',
    otherUserName: nom,
    lastMessage: dernierMessage,
    lastMessageTime: date,
    unreadCount: nonLus,
  );
}

Widget _application(MessagingProvider provider, {bool sombre = true}) {
  return ChangeNotifierProvider<MessagingProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: OmniTheme.clair(),
      darkTheme: OmniTheme.sombre(),
      themeMode: sombre ? ThemeMode.dark : ThemeMode.light,
      home: const MessagesListPage(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Liste des conversations — refonte mobile', () {
    testWidgets('affiche le titre, la recherche et les conversations',
        (tester) async {
      final provider = _ProviderHorsLigne()
        ..addOrUpdateConversation(
          _conversation(
            id: 'c1',
            nom: 'Alice Dupont',
            dernierMessage: 'À demain !',
            nonLus: 3,
          ),
        )
        ..addOrUpdateConversation(
          _conversation(
            id: 'c2',
            nom: 'Bob Martin',
            dernierMessage: 'Reçu, merci',
          ),
        );

      await tester.pumpWidget(_application(provider));
      await tester.pump();

      expect(find.text('Messages'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      expect(find.text('Alice Dupont'), findsOneWidget);
      expect(find.text('Bob Martin'), findsOneWidget);
      expect(find.text('À demain !'), findsOneWidget);

      // Compteur de non-lus de la seule conversation non lue.
      expect(find.text('3'), findsOneWidget);
      // Aucune ligne fantôme : deux conversations, deux lignes.
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('la recherche filtre réellement la liste', (tester) async {
      final provider = _ProviderHorsLigne()
        ..addOrUpdateConversation(
            _conversation(id: 'c1', nom: 'Alice Dupont', dernierMessage: 'Salut'))
        ..addOrUpdateConversation(
            _conversation(id: 'c2', nom: 'Bob Martin', dernierMessage: 'Bonjour'));

      await tester.pumpWidget(_application(provider));
      await tester.pump();

      expect(find.text('Alice Dupont'), findsOneWidget);
      expect(find.text('Bob Martin'), findsOneWidget);

      // Filtre sur le nom.
      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pump();
      expect(find.text('Alice Dupont'), findsOneWidget);
      expect(find.text('Bob Martin'), findsNothing);

      // Filtre sur le contenu du dernier message.
      await tester.enterText(find.byType(TextField), 'bonjour');
      await tester.pump();
      expect(find.text('Alice Dupont'), findsNothing);
      expect(find.text('Bob Martin'), findsOneWidget);

      // Aucun résultat : message explicite, jamais une liste vide muette.
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Aucun résultat'), findsOneWidget);
    });

    testWidgets('état vide explicite quand il n’y a aucune conversation',
        (tester) async {
      final provider = _ProviderHorsLigne();

      await tester.pumpWidget(_application(provider));
      await tester.pump();

      expect(find.text('Aucune conversation'), findsOneWidget);
      expect(find.text('Actualiser'), findsOneWidget);
    });

    testWidgets('se construit sans erreur en thème clair comme en thème sombre',
        (tester) async {
      final provider = _ProviderHorsLigne()
        ..addOrUpdateConversation(
          _conversation(id: 'c1', nom: 'Alice', dernierMessage: 'Coucou'),
        );

      final erreurs = <FlutterErrorDetails>[];
      final precedente = FlutterError.onError;
      FlutterError.onError = erreurs.add;

      await tester.pumpWidget(_application(provider, sombre: true));
      await tester.pump();
      await tester.pumpWidget(_application(provider, sombre: false));
      await tester.pump();

      FlutterError.onError = precedente;

      expect(erreurs, isEmpty, reason: 'aucune erreur de rendu ne doit survenir');
      expect(tester.takeException(), isNull);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('horodatage : heure du jour, « Hier », puis date courte',
        (tester) async {
      final maintenant = DateTime.now();
      final provider = _ProviderHorsLigne()
        ..addOrUpdateConversation(
          _conversation(
            id: 'c1',
            nom: 'Conv du jour',
            dernierMessage: 'x',
            date: DateTime(
              maintenant.year,
              maintenant.month,
              maintenant.day,
              14,
              32,
            ),
          ),
        )
        ..addOrUpdateConversation(
          _conversation(
            id: 'c2',
            nom: 'Conv de la veille',
            dernierMessage: 'y',
            date: maintenant.subtract(const Duration(days: 1)),
          ),
        )
        ..addOrUpdateConversation(
          _conversation(
            id: 'c3',
            nom: 'Conv ancienne',
            dernierMessage: 'z',
            date: maintenant.subtract(const Duration(days: 40)),
          ),
        );

      await tester.pumpWidget(_application(provider));
      await tester.pump();

      expect(find.text('14:32'), findsOneWidget);
      expect(find.text('Hier'), findsOneWidget);
      // Date courte jj/mm/aa pour les conversations de plus d'une semaine.
      final ancien = maintenant.subtract(const Duration(days: 40));
      final attendu =
          '${ancien.day.toString().padLeft(2, '0')}/${ancien.month.toString().padLeft(2, '0')}/${ancien.year.toString().substring(2)}';
      expect(find.text(attendu), findsOneWidget);
    });
  });
}
