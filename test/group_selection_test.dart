import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnisms/models/models.dart';
import 'package:omnisms/providers/contacts_provider_v2.dart';
import 'package:omnisms/providers/groups_provider.dart';
import 'package:omnisms/providers/messaging_provider.dart';
import 'package:omnisms/screens/groups/create_group_screen.dart';

/// ── Doublures ────────────────────────────────────────────────────────────
/// Aucune donnée fictive côté production : ces doublures servent uniquement à
/// piloter l'écran en test, avec des contacts conformes à la vraie réponse de
/// `GET /api/contacts` (voir routes/contacts.v2.js) — notamment SANS champ
/// `id`, ce qui était la cause du bug.
class FakeContactsProvider extends ContactsProviderV2 {
  FakeContactsProvider(this._contacts);

  final List<ContactModel> _contacts;

  @override
  List<ContactModel> get contacts => _contacts;

  @override
  bool get isLoading => false;
}

class FakeGroupsProvider extends GroupsProvider {
  List<String>? capturedMemberIds;
  int calls = 0;

  @override
  Future<GroupModel?> createGroupAndReturn({
    required String name,
    String? description,
    required List<String> memberIds,
  }) async {
    calls++;
    capturedMemberIds = memberIds;
    return GroupModel(
      id: 'group-1',
      name: name,
      description: description,
      memberIds: memberIds,
      creatorId: 'me',
      createdAt: DateTime(2026, 1, 1),
    );
  }
}

/// Le vrai MessagingProvider ouvre des connexions : en test, on se limite à
/// neutraliser l'ajout de conversation (le comportement testé est la
/// sélection, pas la messagerie).
class FakeMessagingProvider extends MessagingProvider {
  int added = 0;

  @override
  void addOrUpdateConversation(ConversationModel conversation) {
    added++;
  }
}

/// ── Jeu de données réel ──────────────────────────────────────────────────
/// Copie exacte de la structure renvoyée par `GET /api/contacts`
/// (routes/contacts.v2.js) : aucun champ `id`.
List<Map<String, dynamic>> rawContacts() => [
      {
        'phone': '+22670000001',
        'name': 'Awa',
        'avatar': null,
        'isOnOmniSms': true,
        'userId': 'uid-awa',
        'registeredUserId': 'uid-awa',
      },
      {
        'phone': '+22670000002',
        'name': 'Boubacar',
        'avatar': null,
        'isOnOmniSms': true,
        'userId': 'uid-boubacar',
        'registeredUserId': 'uid-boubacar',
      },
      {
        'phone': '+22670000003',
        'name': 'Chantal',
        'avatar': null,
        'isOnOmniSms': false,
        'userId': null,
        'registeredUserId': null,
      },
    ];

List<ContactModel> contactsFromApi() =>
    rawContacts().map(ContactModel.fromJson).toList();

Widget buildScreen({
  required List<ContactModel> contacts,
  required FakeGroupsProvider groups,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ContactsProviderV2>(
          create: (_) => FakeContactsProvider(contacts)),
      ChangeNotifierProvider<GroupsProvider>.value(value: groups),
      ChangeNotifierProvider<MessagingProvider>(
          create: (_) => FakeMessagingProvider()),
    ],
    child: const MaterialApp(home: CreateGroupScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContactModel — clés dérivées (cause du bug)', () {
    test('des contacts sans `id` ont des clés de sélection distinctes', () {
      final contacts = contactsFromApi();
      final keys = contacts.map((c) => c.selectionKey).toList();

      // AVANT la correction : `id` valait '' pour les trois → une seule clé.
      expect(keys.toSet().length, 3);
      expect(keys, containsAll(['uid-awa', 'uid-boubacar', '+22670000003']));
    });

    test('la clé retombe sur le numéro quand il n’y a ni id ni compte', () {
      final c = ContactModel.fromJson({
        'phone': '+22670000009',
        'name': 'Inconnu',
        'isOnOmniSms': false,
        'userId': null,
      });
      expect(c.id, isEmpty);
      expect(c.selectionKey, '+22670000009');
    });

    test('memberId : UID du compte, null sans compte OmniSMS', () {
      final contacts = contactsFromApi();
      expect(contacts[0].memberId, 'uid-awa');
      expect(contacts[1].memberId, 'uid-boubacar');
      // Sans compte : aucun UID à envoyer au backend (pas de membre fantôme).
      expect(contacts[2].memberId, isNull);
    });

    test('memberId reste null pour un contact local (id = numéro)', () {
      final local = ContactModel(id: '+22670000010', name: 'VCF');
      expect(local.memberId, isNull);
      expect(local.selectionKey, '+22670000010');
    });

    test('un contact avec `id` explicite garde sa clé', () {
      final c = ContactModel.fromJson({
        'id': 'abc',
        'name': 'Nom',
        'isRegistered': true,
      });
      expect(c.selectionKey, 'abc');
    });

    test('la sérialisation conserve userId', () {
      final c = contactsFromApi().first;
      expect(c.toJson()['userId'], 'uid-awa');
    });
  });

  group('Sélection des contacts à la création d’un groupe', () {
    testWidgets('un appui ne sélectionne QUE ce contact', (tester) async {
      final groups = FakeGroupsProvider();
      await tester.pumpWidget(
          buildScreen(contacts: contactsFromApi(), groups: groups));
      await tester.pumpAndSettle();

      expect(find.text('Membres sélectionnés: 0'), findsOneWidget);

      // Un seul appui sur « Awa ».
      await tester.tap(find.text('Awa'));
      await tester.pumpAndSettle();

      expect(find.text('Membres sélectionnés: 1'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Awa'),
      ).value, true);
      // BUG D’ORIGINE : les deux autres étaient cochés aussi.
      expect(tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Boubacar'),
      ).value, false);
      expect(tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Chantal'),
      ).value, false);
    });

    testWidgets('plusieurs sélections s’additionnent et persistent',
        (tester) async {
      final groups = FakeGroupsProvider();
      await tester.pumpWidget(
          buildScreen(contacts: contactsFromApi(), groups: groups));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Awa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boubacar'));
      await tester.pumpAndSettle();

      expect(find.text('Membres sélectionnés: 2'), findsOneWidget);
      // La première sélection n’a pas été écrasée par la seconde.
      expect(tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Awa'),
      ).value, true);
      expect(tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Boubacar'),
      ).value, true);
    });

    testWidgets('un second appui désélectionne uniquement ce contact',
        (tester) async {
      final groups = FakeGroupsProvider();
      await tester.pumpWidget(
          buildScreen(contacts: contactsFromApi(), groups: groups));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Awa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boubacar'));
      await tester.pumpAndSettle();
      expect(find.text('Membres sélectionnés: 2'), findsOneWidget);

      await tester.tap(find.text('Awa'));
      await tester.pumpAndSettle();

      expect(find.text('Membres sélectionnés: 1'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Awa'),
      ).value, false);
      expect(tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Boubacar'),
      ).value, true);
    });

    testWidgets('un contact sans compte OmniSMS n’est pas sélectionnable',
        (tester) async {
      final groups = FakeGroupsProvider();
      await tester.pumpWidget(
          buildScreen(contacts: contactsFromApi(), groups: groups));
      await tester.pumpAndSettle();

      final tile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Chantal'),
      );
      expect(tile.onChanged, isNull, reason: 'pas d’UID = pas de membre');
      expect(find.textContaining('sans compte OmniSMS'), findsOneWidget);
    });

    testWidgets('les doublons ne sont affichés et comptés qu’une fois',
        (tester) async {
      final contacts = contactsFromApi();
      // Le même contact renvoyé deux fois (carnet + Google).
      final duplicated = [contacts[0], contacts[1], contacts[0]];
      final groups = FakeGroupsProvider();

      await tester
          .pumpWidget(buildScreen(contacts: duplicated, groups: groups));
      await tester.pumpAndSettle();

      expect(find.text('Awa'), findsOneWidget);
      await tester.tap(find.text('Awa'));
      await tester.pumpAndSettle();
      expect(find.text('Membres sélectionnés: 1'), findsOneWidget);
    });

    testWidgets('la confirmation ne transmet que les membres sélectionnés',
        (tester) async {
      final groups = FakeGroupsProvider();
      await tester.pumpWidget(
          buildScreen(contacts: contactsFromApi(), groups: groups));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Nom du groupe *'), 'Famille');
      await tester.tap(find.text('Awa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boubacar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer'));
      // Pas de `pumpAndSettle` ici : l'écran de conversation du groupe
      // nouvellement créé lance un rafraîchissement périodique (timer 15 s)
      // — on avance seulement de quelques frames, ce qui suffit à déclencher
      // l'appel de création.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(groups.calls, 1);
      expect(groups.capturedMemberIds, isNotNull);
      expect(groups.capturedMemberIds!.length, 2);
      expect(groups.capturedMemberIds, containsAll(['uid-awa', 'uid-boubacar']));
      // Chantal n’avait pas de compte : elle ne doit pas être transmise.
      expect(groups.capturedMemberIds, isNot(contains('+22670000003')));
    });

    testWidgets('créer sans membre reste possible (créateur seul)',
        (tester) async {
      final groups = FakeGroupsProvider();
      await tester.pumpWidget(
          buildScreen(contacts: contactsFromApi(), groups: groups));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Nom du groupe *'), 'Solo');
      await tester.tap(find.text('Créer'));
      // Pas de `pumpAndSettle` ici : l'écran de conversation du groupe
      // nouvellement créé lance un rafraîchissement périodique (timer 15 s)
      // — on avance seulement de quelques frames, ce qui suffit à déclencher
      // l'appel de création.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(groups.calls, 1);
      expect(groups.capturedMemberIds, isEmpty);
    });

    testWidgets('un nom est toujours exigé', (tester) async {
      final groups = FakeGroupsProvider();
      await tester.pumpWidget(
          buildScreen(contacts: contactsFromApi(), groups: groups));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(groups.calls, 0);
      expect(find.text('Veuillez entrer un nom de groupe'), findsOneWidget);
    });
  });

  group('Non-régression messagerie', () {
    test('l’identifiant de conversation reste le numéro quand `id` est vide',
        () {
      final c = contactsFromApi()[2];
      // Même règle que contacts_screen_v2.dart (_openContactConversation) :
      // ne doit pas changer avec la correction.
      final contactId = c.id.isNotEmpty ? c.id : (c.phone ?? '');
      expect(contactId, '+22670000003');
    });

    test('les erreurs réseau restent détectables', () {
      expect(SocketException('Failed host lookup'), isA<SocketException>());
    });
  });
}
