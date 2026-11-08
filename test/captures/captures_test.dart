// ─────────────────────────────────────────────────────────────────────────
// CAPTURES D'ÉCRAN — liste des conversations et conversation.
//
// Ce fichier produit de vraies images (goldens) au format téléphone, en thème
// sombre et en thème clair. Il est volontairement écrit avec des API
// présentes AVANT et APRÈS la refonte (ThemeProvider.lightTheme/darkTheme,
// MessagesListPage, ModernMessageBubble, addOrUpdateConversation), afin de
// pouvoir être exécuté tel quel sur l'ancienne version du code : les captures
// « avant » et « après » sont donc produites par le même scénario.
//
// Rendu : la police Roboto du SDK Flutter est chargée explicitement, sinon les
// tests afficheraient des carrés à la place du texte.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data' show ByteData;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, MethodCall, MethodChannel, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart' show SingleChildWidget;
import 'package:provider/provider.dart';

import 'package:omnisms/models/conversation_model.dart';
import 'package:omnisms/models/message_model.dart';
import 'package:omnisms/providers/messaging_provider.dart';
import 'package:omnisms/providers/theme_provider.dart';
import 'package:omnisms/services/presence_service.dart';
import 'package:omnisms/services/realtime_service.dart';
import 'package:omnisms/screens/messaging/messages_list_page.dart';
import 'package:omnisms/widgets/chat/modern_message_bubble.dart';

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

Widget _ecran({
  required Widget child,
  required bool sombre,
  required List<SingleChildWidget> providers,
}) {
  final theme = sombre ? ThemeProvider.darkTheme : ThemeProvider.lightTheme;
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
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
    ),
  );
}

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
    // `ThemeProvider` lit les préférences partagées : sans ce simulacre, le
    // canal de plateforme lève une exception et le test est marqué en échec
    // (les captures, elles, sont tout de même produites).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall appel) async {
        if (appel.method == 'getAll') return <String, Object>{};
        return null;
      },
    );
    policesDisponibles = await chargerPolice();
    // Les bundles d'assets ne sont pas chargés dans les tests unitaires :
    // cette ligne évite une erreur si un widget tente de les lire.
    try {
      await rootBundle.load('AssetManifest.bin');
    } catch (_) {
      // Sans importance pour ces captures.
    }
  });

  group('Captures — liste des conversations', () {
    for (final sombre in <bool>[true, false]) {
      testWidgets(sombre ? 'thème sombre' : 'thème clair', (tester) async {
        if (!policesDisponibles) {
          markTestSkipped('Polices du SDK Flutter introuvables : '
              'captures non comparables sur cette machine.');
          return;
        }
        final provider = _ProviderHorsLigne();
        for (final conv in _conversations()) {
          provider.addOrUpdateConversation(conv);
        }

        final presence = PresenceService(realtime: _PresenceInerte());

        // Format téléphone réel : sans cela, la capture occuperait un coin
        // de la surface de test (800×600 par défaut).
        tester.view.physicalSize = const Size(822, 1720);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_ecran(
          sombre: sombre,
          providers: [
            ChangeNotifierProvider<MessagingProvider>.value(value: provider),
            ChangeNotifierProvider<PresenceService>.value(value: presence),
          ],
          child: const MessagesListPage(),
        ));
        await tester.pump();

        // Le rendu lui-même est vérifié partout : c'est ce qui garantit
        // qu'aucune exception ni dépassement ne se produit.
        expect(find.text('Alice Dupont'), findsOneWidget);
        expect(find.text('Groupe Équipe'), findsOneWidget);

        if (comparerAuPixel) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/liste_conversations_${sombre ? 'sombre' : 'clair'}.png',
            ),
          );
        } else {
          await tester.pump(const Duration(milliseconds: 200));
        }

        // Libération explicite : MessagingProvider démarre un minuteur
        // d'interrogation ; sans cela, le framework de test signale un
        // minuteur en attente (les tearDowns passent trop tard).
        provider.dispose();
        presence.dispose();
      });
    }
  });

  group('Captures — conversation', () {
    for (final sombre in <bool>[true, false]) {
      testWidgets(sombre ? 'thème sombre' : 'thème clair', (tester) async {
        if (!policesDisponibles) {
          markTestSkipped('Polices du SDK Flutter introuvables : '
              'captures non comparables sur cette machine.');
          return;
        }
        tester.view.physicalSize = const Size(822, 1720);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_ecran(
          sombre: sombre,
          providers: [
            ChangeNotifierProvider<MessagingProvider>(
                create: (_) => _ProviderHorsLigne()),
            ChangeNotifierProvider<PresenceService>(
                create: (_) => PresenceService(realtime: _PresenceInerte())),
          ],
          child: _conversation(sombre),
        ));
        await tester.pump();

        expect(find.text('Salut ! Tu as reçu le colis ?'), findsOneWidget);
        expect(find.text('Oui, livré ce matin 👍'), findsOneWidget);

        if (comparerAuPixel) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/conversation_${sombre ? 'sombre' : 'clair'}.png',
            ),
          );
        } else {
          await tester.pump(const Duration(milliseconds: 200));
        }
      });
    }
  });
}
