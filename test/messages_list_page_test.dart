import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnisms/models/conversation_model.dart';
import 'package:omnisms/providers/messaging_provider.dart';
import 'package:omnisms/screens/messaging/messages_list_page.dart';
import 'package:omnisms/services/presence_service.dart';
import 'package:omnisms/services/realtime_service.dart';
import 'package:omnisms/theme/omni_design.dart';
import 'package:omnisms/theme/omni_theme.dart';

/// Source de présence pilotable : reflète exactement ce que répondrait le
/// backend (online / offline), sans jamais rien simuler d'autre.
class _PresenceControlee implements PresenceSource {
  _PresenceControlee(this.etats);

  final Map<String, PresenceState> etats;

  @override
  RealtimeStatus get status => RealtimeStatus.connected;

  @override
  Stream<RealtimeStatus> get statusStream => const Stream<RealtimeStatus>.empty();

  @override
  Stream<PresenceInfo> get presenceStream => const Stream<PresenceInfo>.empty();

  @override
  Future<PresenceInfo> checkPresence(String uid,
          {Duration timeout = const Duration(seconds: 6)}) async =>
      PresenceInfo(
        uid: uid,
        state: etats[uid] ?? PresenceState.unknown,
        lastSeen: DateTime(2026, 10, 20, 9),
      );
}

/// Source de présence inerte : la liste des conversations suit la présence
/// des contacts affichés, il faut donc un service — mais aucun appel réseau
/// n'est fait pendant ces tests.
class _PresenceInerte implements PresenceSource {
  @override
  RealtimeStatus get status => RealtimeStatus.disconnected;

  @override
  Stream<RealtimeStatus> get statusStream => const Stream<RealtimeStatus>.empty();

  @override
  Stream<PresenceInfo> get presenceStream => const Stream<PresenceInfo>.empty();

  @override
  Future<PresenceInfo> checkPresence(String uid,
          {Duration timeout = const Duration(seconds: 6)}) async =>
      PresenceInfo.unknown(uid);
}

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

Widget _application(
  MessagingProvider provider, {
  required PresenceService presence,
  bool sombre = true,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MessagingProvider>.value(value: provider),
      ChangeNotifierProvider<PresenceService>.value(value: presence),
    ],
    child: MaterialApp(
      theme: OmniTheme.clair(),
      darkTheme: OmniTheme.sombre(),
      themeMode: sombre ? ThemeMode.dark : ThemeMode.light,
      home: const MessagesListPage(),
    ),
  );
}

/// Crée le service de présence utilisé par les tests et garantit sa
/// libération (il démarre un minuteur périodique).
PresenceService _presenceDeTest() {
  final service = PresenceService(realtime: _PresenceInerte());
  addTearDown(service.dispose);
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Liste des conversations — refonte mobile', () {
    testWidgets('affiche le titre, la recherche et les conversations',
        (tester) async {
      final presence = _presenceDeTest();
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

      await tester.pumpWidget(_application(provider, presence: presence));
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
      final presence = _presenceDeTest();
      final provider = _ProviderHorsLigne()
        ..addOrUpdateConversation(
            _conversation(id: 'c1', nom: 'Alice Dupont', dernierMessage: 'Salut'))
        ..addOrUpdateConversation(
            _conversation(id: 'c2', nom: 'Bob Martin', dernierMessage: 'Bonjour'));

      await tester.pumpWidget(_application(provider, presence: presence));
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
      final presence = _presenceDeTest();
      final provider = _ProviderHorsLigne();

      await tester.pumpWidget(_application(provider, presence: presence));
      await tester.pump();

      expect(find.text('Aucune conversation'), findsOneWidget);
      expect(find.text('Actualiser'), findsOneWidget);
    });

    testWidgets('se construit sans erreur en thème clair comme en thème sombre',
        (tester) async {
      final presence = _presenceDeTest();
      final provider = _ProviderHorsLigne()
        ..addOrUpdateConversation(
          _conversation(id: 'c1', nom: 'Alice', dernierMessage: 'Coucou'),
        );

      final erreurs = <FlutterErrorDetails>[];
      final precedente = FlutterError.onError;
      FlutterError.onError = erreurs.add;

      await tester.pumpWidget(_application(provider, presence: presence, sombre: true));
      await tester.pump();
      await tester.pumpWidget(_application(provider, presence: presence, sombre: false));
      await tester.pump();

      FlutterError.onError = precedente;

      expect(erreurs, isEmpty, reason: 'aucune erreur de rendu ne doit survenir');
      expect(tester.takeException(), isNull);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('horodatage : heure du jour, « Hier », puis date courte',
        (tester) async {
      final maintenant = DateTime.now();
      final presence = _presenceDeTest();
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

      await tester.pumpWidget(_application(provider, presence: presence));
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


  group('Liste des conversations — présence réelle', () {
    /// La pastille verte n'existe QUE si le backend a confirmé une session.
    bool _pastilleVerte(Widget widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).color == OmniPalette.succes;

    testWidgets('la pastille n’apparaît que pour un contact confirmé en ligne',
        (tester) async {
      final source = _PresenceControlee({
        'usr-c1': PresenceState.online,
        'usr-c2': PresenceState.offline,
        // 'usr-c3' absent ⇒ « inconnu », volontairement.
      });
      final presence = PresenceService(realtime: source);
      addTearDown(presence.dispose);

      final provider = _ProviderHorsLigne()
        ..addOrUpdateConversation(_conversation(
            id: 'c1', nom: 'Alice', dernierMessage: 'A', nonLus: 0))
        ..addOrUpdateConversation(_conversation(
            id: 'c2', nom: 'Bob', dernierMessage: 'B'))
        ..addOrUpdateConversation(_conversation(
            id: 'c3', nom: 'Claire', dernierMessage: 'C'));

      await tester.pumpWidget(
          _application(provider, presence: presence));
      await tester.pump();
      // Laisse le temps aux rafraîchissements asynchrones.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Un seul contact est en ligne ⇒ une seule pastille.
      expect(
        find.byWidgetPredicate(_pastilleVerte),
        findsOneWidget,
        reason: 'ni l’offline ni l’inconnu n’affichent de pastille',
      );
    });

    testWidgets('un contact « inconnu » n’est jamais marqué hors ligne',
        (tester) async {
      final source = _PresenceControlee({});
      final presence = PresenceService(realtime: source);
      addTearDown(presence.dispose);

      final provider = _ProviderHorsLigne()
        ..addOrUpdateConversation(
            _conversation(id: 'c1', nom: 'Alice', dernierMessage: 'A'));

      await tester.pumpWidget(_application(provider, presence: presence));
      await tester.pump(const Duration(milliseconds: 100));

      expect(presence.stateOf('usr-c1').isUnknown, isTrue);
      expect(presence.stateOf('usr-c1').isOffline, isFalse,
          reason: 'l’absence de réponse n’est pas une preuve de déconnexion');
      expect(find.byWidgetPredicate(_pastilleVerte), findsNothing);
    });
  });
}

