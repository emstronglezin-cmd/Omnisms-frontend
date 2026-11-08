import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnisms/models/conversation_model.dart';
import 'package:omnisms/providers/messaging_provider.dart';
import 'package:omnisms/screens/messaging/conversation_screen.dart';
import 'package:omnisms/services/notification_navigation.dart';
import 'package:omnisms/services/presence_service.dart';
import 'package:omnisms/services/realtime_service.dart';
import 'package:omnisms/theme/omni_theme.dart';

/// Fournisseur **sans réseau** : neutralise les appels au backend pour que le
/// test ne dépende jamais d'un serveur.
class _ProviderHorsLigne extends MessagingProvider {
  @override
  Future<void> loadConversations() async {}

  @override
  Future<void> loadMessages(String conversationId) async {}

  // Ces deux méthades interrogent le backend : sous l'horloge simulée des
  // tests, un vrai appel HTTP ne se terminerait jamais.
  @override
  Future<void> markConversationAsRead(String conversationId) async {}

  @override
  void setActiveConversation(String? conversationId) {}
}

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

ConversationModel _conversation(String id, String nom) => ConversationModel(
      id: id,
      otherUserId: 'usr-$id',
      otherUserName: nom,
      lastMessage: 'Dernier message',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Le service est un singleton : on repart d'un état propre.
    NotificationNavigation.instance.reinitialiserPourTest();
  });

  Future<MessagingProvider> _monterApplication(
    WidgetTester tester, {
    required List<ConversationModel> conversations,
  }) async {
    final provider = _ProviderHorsLigne();
    for (final conv in conversations) {
      provider.addOrUpdateConversation(conv);
    }
    final presence = PresenceService(realtime: _PresenceInerte());
    addTearDown(presence.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MessagingProvider>.value(value: provider),
          ChangeNotifierProvider<PresenceService>.value(value: presence),
        ],
        child: MaterialApp(
          navigatorKey: navigateurGlobalKey,
          theme: OmniTheme.sombre(),
          home: const Scaffold(body: Center(child: Text('Accueil'))),
        ),
      ),
    );
    await tester.pump();
    return provider;
  }

  testWidgets('le tap ouvre réellement la bonne conversation', (tester) async {
    await _monterApplication(
      tester,
      conversations: [_conversation('c1', 'Alice'), _conversation('c2', 'Bob')],
    );

    final ouvert = await NotificationNavigation.instance.ouvrir('c2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(ouvert, isTrue);
    expect(find.byType(ConversationScreen), findsOneWidget);
    // Le nom affiché est bien celui de la conversation visée.
    expect(find.text('Bob'), findsWidgets);

    // L'utilisateur quitte la conversation : le suivi de présence est libéré.
    navigateurGlobalKey.currentState?.pop();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('une conversation inconnue ne provoque aucun écran vide',
      (tester) async {
    await _monterApplication(
      tester,
      conversations: [_conversation('c1', 'Alice')],
    );

    final ouvert = await NotificationNavigation.instance.ouvrir('inconnue');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(ouvert, isFalse);
    expect(find.byType(ConversationScreen), findsNothing);
    // L'utilisateur reste là où il était.
    expect(find.text('Accueil'), findsOneWidget);
  });

  testWidgets('un identifiant vide est ignoré', (tester) async {
    await _monterApplication(tester, conversations: []);
    expect(await NotificationNavigation.instance.ouvrir(''), isFalse);
  });

  test('sans interface montée, la conversation est mise en attente', () async {
    // Aucun widget n'est monté : le contexte de navigation n'existe pas.
    final ouvert = await NotificationNavigation.instance.ouvrir('c1');

    expect(ouvert, isFalse);
    expect(NotificationNavigation.instance.aUneConversationEnAttente, isTrue);
  });

  testWidgets('la conversation en attente s’ouvre dès que l’interface existe',
      (tester) async {
    // 1. Notification reçue avant que l'interface soit prête.
    await NotificationNavigation.instance.ouvrir('c1');
    expect(NotificationNavigation.instance.aUneConversationEnAttente, isTrue);

    // 2. L'interface se monte (l'utilisateur s'est authentifié).
    await _monterApplication(
      tester,
      conversations: [_conversation('c1', 'Alice')],
    );

    // 3. Traitement de l'attente.
    final ouvert =
        await NotificationNavigation.instance.traiterConversationEnAttente();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(ouvert, isTrue);
    expect(find.byType(ConversationScreen), findsOneWidget);
    expect(NotificationNavigation.instance.aUneConversationEnAttente, isFalse);

    navigateurGlobalKey.currentState?.pop();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
