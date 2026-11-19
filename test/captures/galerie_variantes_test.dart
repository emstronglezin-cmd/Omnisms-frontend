import 'dart:io';
import 'dart:typed_data' show ByteData;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:omnisms/models/conversation_model.dart';
import 'package:omnisms/models/message_model.dart';
import 'package:omnisms/widgets/chat/modern_message_bubble.dart';
import 'package:omnisms/providers/messaging_provider.dart';
import 'package:omnisms/screens/messaging/messages_list_page.dart';
import 'package:omnisms/services/presence_service.dart';
import 'package:omnisms/services/realtime_service.dart';
import 'package:omnisms/theme/omni_motion.dart';
import 'package:omnisms/theme/omni_theme.dart';
import 'package:omnisms/providers/theme_provider.dart';
import 'package:omnisms/widgets/common/liquid_glass.dart';

/// Taille d'écran de téléphone (logique) utilisée pour les captures.
const double kLargeurEcran = 411;
const double kHauteurEcran = 860;

/// Dossier des polices du SDK Flutter (dépend de la machine).
String? _dossierPolices() {
  final candidats = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
    '${Platform.environment['HOME'] ?? ''}/.cache/flutter/bin/cache/artifacts/material_fonts',
    '/usr/lib/flutter/bin/cache/artifacts/material_fonts',
  ];
  for (final chemin in candidats) {
    if (chemin.isNotEmpty && Directory(chemin).existsSync()) return chemin;
  }
  return null;
}

/// Charge Roboto pour que le texte soit rendu lisiblement.
///
/// Renvoie `false` si les polices du SDK sont introuvables : le test est
/// alors ignoré (les goldens dépendent de la police, une comparaison
/// échouerait à tort sur une machine qui ne l'a pas).
Future<bool> chargerPolice() async {
  final base = _dossierPolices();
  if (base == null) return false;

  var charge = false;
  for (final nom in <String>['Roboto-Regular', 'Roboto-Medium', 'Roboto-Bold']) {
    final fichier = File('$base/$nom.ttf');
    if (!fichier.existsSync()) continue;
    final octets = fichier.readAsBytesSync();
    final chargeur = FontLoader(nom)
      ..addFont(Future<ByteData>.value(octets.buffer.asByteData()));
    await chargeur.load();
    charge = true;
  }
  return charge;
}

/// Vrai si les polices sont disponibles (sinon les tests sont ignorés).
bool policesDisponibles = false;

/// Vrai si l'on doit comparer les images au pixel près.
///
/// Les images de référence ont été produites **sur Linux**, avec la police
/// Roboto du SDK. Le rendu du texte diffère d'une plateforme à l'autre
/// (antialiasing) : sur macOS, la comparaison échoue à environ 1 % des
/// pixels pour une interface identique — un faux négatif, constaté sur la
/// CI. La comparaison stricte est donc réservée à Linux ET activée
/// explicitement (variable d'environnement). Partout ailleurs, le scénario
/// est tout de même rendu : une exception, un dépassement de contrainte
/// overflow ou un widget manquant fera échouer le test.
bool get comparerAuPixel => Platform.isLinux &&
    Platform.environment['OMNI_COMPARER_CAPTURES'] == '1';

/// Source de présence inerte : la liste suit la présence des contacts
/// affichés, il faut donc un service — sans aucun appel réseau ici.
class _PresenceInerte implements PresenceSource {
  @override
  RealtimeStatus get status => RealtimeStatus.disconnected;

  @override
  Stream<RealtimeStatus> get statusStream =>
      const Stream<RealtimeStatus>.empty();

  @override
  Stream<PresenceInfo> get presenceStream =>
      const Stream<PresenceInfo>.empty();

  @override
  Future<PresenceInfo> checkPresence(String uid,
          {Duration timeout = const Duration(seconds: 6)}) async =>
      PresenceInfo.unknown(uid);
}

/// Fournisseur sans réseau : les conversations sont injectées via l'API
/// publique `addOrUpdateConversation`.
class _ProviderHorsLigne extends MessagingProvider {
  @override
  Future<void> loadConversations() async {}

  @override
  Future<void> loadMessages(String conversationId) async {}

  @override
  Future<void> markConversationAsRead(String conversationId) async {}

  @override
  void setActiveConversation(String? conversationId) {}
}

List<ConversationModel> _conversations() {
  final maintenant = DateTime.now();
  return <ConversationModel>[
    ConversationModel(
      id: 'c1',
      otherUserId: 'u1',
      otherUserName: 'Alice Dupont',
      lastMessage: 'On se retrouve à 18h devant la gare ?',
      lastMessageTime: maintenant.subtract(const Duration(minutes: 12)),
      unreadCount: 3,
      channel: 'internal',
    ),
    ConversationModel(
      id: 'c2',
      otherUserId: 'u2',
      otherUserName: 'Bob Martin',
      lastMessage: 'Reçu, merci beaucoup !',
      lastMessageTime: maintenant.subtract(const Duration(hours: 2)),
      channel: 'sms',
    ),
    ConversationModel(
      id: 'c3',
      otherUserId: 'u3',
      otherUserName: 'Groupe Équipe',
      groupName: 'Groupe Équipe',
      isGroup: true,
      lastMessage: 'Présent pour la réunion de demain.',
      lastMessageTime: maintenant.subtract(const Duration(days: 1)),
      unreadCount: 12,
      channel: 'internal',
    ),
    ConversationModel(
      id: 'c4',
      otherUserId: 'u4',
      otherUserName: 'Claire Ngoma',
      lastMessage: 'Bonne soirée à toi 😊',
      lastMessageTime: maintenant.subtract(const Duration(days: 3)),
      channel: 'whatsapp',
    ),
  ];
}


/// Écran enveloppé dans un thème de variante donné.
Widget _ecranVariante({required Widget child, required ThemeData theme}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'Roboto-Regular'),
      primaryTextTheme:
          theme.primaryTextTheme.apply(fontFamily: 'Roboto-Regular'),
    ),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(kLargeurEcran, kHauteurEcran),
        devicePixelRatio: 2.0,
        padding: EdgeInsets.only(top: 24, bottom: 0),
      ),
      child: SizedBox(
        width: kLargeurEcran,
        height: kHauteurEcran,
        child: child,
      ),
    ),
  );
}

/// Conversation reconstituée pour la capture : les mêmes bulles que l'écran
/// de conversation réel (ModernMessageBubble).
Widget _conversation(bool sombre) {
  final maintenant = DateTime.now();
  return Scaffold(
    appBar: AppBar(
      leading: const Icon(Icons.arrow_back),
      titleSpacing: 0,
      title: Row(
        children: [
          const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 20)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Alice Dupont',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text('En ligne',
                  style: TextStyle(
                      fontSize: 12,
                      color: sombre ? Colors.white70 : Colors.grey[600])),
            ],
          ),
        ],
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: <Widget>[
        ModernMessageBubble(
          message: 'Salut ! Tu as reçu le colis ?',
          isMe: false,
          timestamp: maintenant.subtract(const Duration(minutes: 20)),
        ),
        ModernMessageBubble(
          message: 'Oui, livré ce matin 👍',
          isMe: true,
          timestamp: maintenant.subtract(const Duration(minutes: 18)),
          status: MessageStatus.read,
        ),
        ModernMessageBubble(
          message: 'Parfait. On se retrouve à 18h devant la gare ?',
          isMe: false,
          timestamp: maintenant.subtract(const Duration(minutes: 15)),
        ),
        ModernMessageBubble(
          message: 'Ça me va. J’apporte les documents pour le dossier.',
          isMe: true,
          timestamp: maintenant.subtract(const Duration(minutes: 12)),
          status: MessageStatus.delivered,
        ),
        ModernMessageBubble(
          message: 'À tout de suite !',
          isMe: true,
          timestamp: maintenant.subtract(const Duration(minutes: 11)),
          status: MessageStatus.sending,
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    OmniMouvementTest.desactivees = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall appel) async {
        if (appel.method == 'getAll') return <String, Object>{};
        return null;
      },
    );
    policesDisponibles = await chargerPolice();
    try {
      await rootBundle.load('AssetManifest.bin');
    } catch (_) {}
  });

  Future<void> liste(
    WidgetTester tester, {
    required String nom,
    required ThemeData theme,
  }) async {
    final provider = _ProviderHorsLigne();
    for (final conv in _conversations()) {
      provider.addOrUpdateConversation(conv);
    }
    final presence = PresenceService(realtime: _PresenceInerte());

    tester.view.physicalSize = const Size(411, 860) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MessagingProvider>.value(value: provider),
          ChangeNotifierProvider<PresenceService>.value(value: presence),
        ],
        child: _ecranVariante(theme: theme, child: const MessagesListPage()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Alice Dupont'), findsOneWidget);

    if (comparerAuPixel) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/galerie/$nom.png'),
      );
    }
    provider.dispose();
    presence.dispose();
  }

  Future<void> conversation(
    WidgetTester tester, {
    required String nom,
    required ThemeData theme,
  }) async {
    tester.view.physicalSize = const Size(822, 1720);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _ecranVariante(theme: theme, child: _conversation(true)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Salut ! Tu as reçu le colis ?'), findsOneWidget);

    if (comparerAuPixel) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/galerie/$nom.png'),
      );
    }
  }

  group('Galerie — liste des conversations', () {
    testWidgets('classique', (tester) async {
      await liste(tester, nom: 'liste_classique', theme: OmniTheme.sombre());
    });

    testWidgets('nova', (tester) async {
      await liste(tester, nom: 'liste_nova', theme: OmniTheme.novaSombre());
    });
  });

  group('Galerie — conversation', () {
    testWidgets('classique', (tester) async {
      await conversation(
        tester,
        nom: 'conversation_classique',
        theme: OmniTheme.sombre(),
      );
    });

    testWidgets('nova', (tester) async {
      await conversation(
        tester,
        nom: 'conversation_nova',
        theme: OmniTheme.novaSombre(),
      );
    });
  });

  /// Boutons du bas : les widgets RÉELS des deux identités, mêmes onglets.
  Future<void> barre(
    WidgetTester tester, {
    required String nom,
    required bool nova,
  }) async {
    tester.view.physicalSize = const Size(822, 560);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final theme = nova ? OmniTheme.novaSombre() : OmniTheme.sombre();
    const onglets = <(IconData, IconData, String)>[
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Messages'),
      (Icons.contacts_outlined, Icons.contacts, 'Contacts'),
      (Icons.group_outlined, Icons.group, 'Groupes'),
      (Icons.settings_outlined, Icons.settings, 'Paramètres'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          backgroundColor:
              nova ? Colors.transparent : theme.scaffoldBackgroundColor,
          extendBody: nova,
          body: OmniFondAurore(
            child: ListView(
              children: [
                for (var i = 0; i < 6; i++)
                  Container(
                    height: 64,
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: nova
                          ? const Color(0xFF152043)
                          : const Color(0xFF171C27),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: nova
              ? OmniBarreFlottante(
                  index: 0,
                  onTap: (_) {},
                  onglets: [
                    for (final o in onglets)
                      OmniOnglet(
                        icone: o.$1,
                        iconeActive: o.$2,
                        libelle: o.$3,
                      ),
                  ],
                )
              : NavigationBar(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  elevation: 0,
                  backgroundColor: theme.colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  destinations: [
                    for (final o in onglets)
                      NavigationDestination(
                        icon: Icon(o.$1),
                        selectedIcon: Icon(o.$2),
                        label: o.$3,
                      ),
                  ],
                ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    if (comparerAuPixel) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/galerie/$nom.png'),
      );
    }
  }

  group('Galerie — boutons du bas', () {
    testWidgets('ancien widget (ce que vous voyiez)', (tester) async {
      await barre(tester, nom: 'barre_avant', nova: false);
    });

    testWidgets('nouveau widget (Nova)', (tester) async {
      await barre(tester, nom: 'barre_apres', nova: true);
    });
  });

  group('Galerie — défaut d’une installation neuve', () {
    testWidgets('ce que montre l’APK au premier lancement', (tester) async {
      // ThemeProvider sans lecture de préférences : c'est le défaut réel de
      // l'application, celui qu'obtient une installation neuve.
      await liste(tester, nom: 'defaut_frais', theme: ThemeProvider().darkTheme);
    });
  });
}
