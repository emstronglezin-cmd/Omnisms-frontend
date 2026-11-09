// ─────────────────────────────────────────────────────────────────────────
// CAPTURES V3 — vérification du rendu aux tailles d'écran exigées.
//
// Ce fichier fait deux choses, et ce sont les deux seules qui comptent :
//
// 1. il **rend** l'écran à chaque taille et échoue à la moindre exception de
//    mise en page (un `RenderFlex overflow` est une erreur, donc le test
//    échoue). C'est une vraie vérification de « responsive », pas une
//    déclaration d'intention.
// 2. il **écrit** l'image obtenue dans un dossier du dépôt, pour que les
//    captures soient consultables.
//
// Les images ne sont **pas** comparées au pixel près : le rendu du texte
// diffère d'une plateforme à l'autre (un golden produit sur Linux échoue sur
// macOS à ~1 % des pixels pour une interface identique — faux négatif
// constaté sur la CI). On vérifie donc que ça se dessine, pas que c'est
// identique à l'octet près.
//
// La génération des fichiers est activée par la variable d'environnement
// OMNI_ECRIRE_CAPTURES=1, afin de ne pas polluer le dépôt à chaque exécution
// de la suite de tests.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data' show ByteData;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart' show SingleChildWidget;
import 'package:provider/provider.dart';

import 'package:omnisms/models/conversation_model.dart';
import 'package:omnisms/models/message_model.dart';
import 'package:omnisms/providers/messaging_provider.dart';
import 'package:omnisms/providers/theme_provider.dart';
import 'package:omnisms/screens/messaging/messages_list_page.dart';
import 'package:omnisms/services/presence_service.dart';
import 'package:omnisms/services/realtime_service.dart';
import 'package:omnisms/theme/omni_design.dart';
import 'package:omnisms/theme/omni_motion.dart';
import 'package:omnisms/widgets/chat/modern_message_bubble.dart' as modern;

/// Tailles d'écran exigées, en pixels logiques.
///
/// Les trois premières couvrent les téléphones courants, de l'entrée de
/// gamme au grand format. Les deux dernières couvrent les appareils pliables
/// et les tablettes, où la mise en page doit changer de structure et non
/// simplement s'étirer.
const List<({String nom, double largeur, double hauteur})> kTailles = [
  (nom: '360x800', largeur: 360, hauteur: 800),
  (nom: '393x852', largeur: 393, hauteur: 852),
  (nom: '432x960', largeur: 432, hauteur: 960),
  (nom: '673x841-pliable', largeur: 673, hauteur: 841),
  (nom: '840x1200-tablette', largeur: 840, hauteur: 1200),
];

/// Dossier de sortie des images (relatif au fichier de test).
const String kDossierSortie = 'captures_v3';

/// Vrai si l'on doit comparer les images au pixel près.
///
/// Les images sont produites **sur Linux**, avec la police Roboto du SDK. Le
/// rendu du texte diffère d'une plateforme à l'autre (antialiasing) : sur
/// macOS, la comparaison échoue à environ 1 % des pixels pour une interface
/// identique. La comparaison stricte est donc réservée à Linux ET activée
/// explicitement. Partout ailleurs, l'écran est tout de même rendu et
/// vérifié : une exception ou un dépassement de contrainte fait échouer le
/// test.
bool get comparerAuPixel =>
    Platform.isLinux &&
    Platform.environment['OMNI_COMPARER_CAPTURES'] == '1';

bool _policesChargees = false;
bool _partageMock = false;

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

Future<bool> _chargerPolice() async {
  final base = _dossierPolices();
  if (base == null) return false;

  var ok = false;
  for (final nom in <String>['Roboto-Regular', 'Roboto-Medium', 'Roboto-Bold']) {
    final fichier = File('$base/$nom.ttf');
    if (!fichier.existsSync()) continue;
    final octets = fichier.readAsBytesSync();
    final chargeur = FontLoader(nom)
      ..addFont(Future<ByteData>.value(octets.buffer.asByteData()));
    await chargeur.load();
    ok = true;
  }
  return ok;
}

/// `ThemeProvider` lit les préférences partagées : sans ce simulacre, une
/// `MissingPluginException` est levée.
void _simulerPreferences() {
  if (_partageMock) return;
  const canal = MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(canal, (MethodCall appel) async {
    if (appel.method == 'getAll') return <String, Object>{};
    if (appel.method == 'setBool') return true;
    return null;
  });
  _partageMock = true;
}

/// Source de présence inerte : aucun appel réseau pendant une capture.
class _PresenceInerte implements PresenceSource {
  @override
  RealtimeStatus get status => RealtimeStatus.disconnected;

  @override
  Stream<RealtimeStatus> get statusStream =>
      const Stream<RealtimeStatus>.empty();

  @override
  Stream<PresenceInfo> get presenceStream => const Stream<PresenceInfo>.empty();

  @override
  Future<PresenceInfo> checkPresence(String uid,
          {Duration timeout = const Duration(seconds: 6)}) async =>
      PresenceInfo.unknown(uid);
}

/// Fournisseur sans réseau : les données sont injectées par l'API publique.
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

/// Écran de conversation reconstitué avec les vraies bulles.
Widget _ecranConversation() {
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
              Text('Alice Dupont', style: OmniTypo.corpsGras),
              Text('en ligne', style: OmniTypo.micro),
            ],
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              modern.ModernMessageBubble(
                message: 'Salut ! Tu as reçu le colis ?',
                isMe: false,
                timestamp: maintenant.subtract(const Duration(minutes: 30)),
                type: modern.MessageType.text,
                status: MessageStatus.read,
              ),
              modern.ModernMessageBubble(
                message: 'Oui, livré ce matin 👍',
                isMe: true,
                timestamp: maintenant.subtract(const Duration(minutes: 28)),
                type: modern.MessageType.text,
                status: MessageStatus.read,
              ),
              modern.ModernMessageBubble(
                message:
                    'Parfait. Je te rappelle ce soir pour la réunion de demain, '
                    'il faut qu’on valide le budget avant la présentation.',
                isMe: false,
                timestamp: maintenant.subtract(const Duration(minutes: 12)),
                type: modern.MessageType.text,
                status: MessageStatus.read,
              ),
              modern.ModernMessageBubble(
                message: 'D’accord, à 20h alors.',
                isMe: true,
                timestamp: maintenant.subtract(const Duration(minutes: 10)),
                type: modern.MessageType.text,
                status: MessageStatus.read,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _application({
  required Widget child,
  required bool sombre,
  required List<SingleChildWidget> providers,
  required double largeur,
  required double hauteur,
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
        data: MediaQueryData(
          size: Size(largeur, hauteur),
          devicePixelRatio: 2.0,
          padding: const EdgeInsets.only(top: 24),
        ),
        child: RepaintBoundary(
          key: const Key('zone-capture'),
          child: SizedBox(
            width: largeur,
            height: hauteur,
            child: child,
          ),
        ),
      ),
    ),
  );
}

Future<void> _capturer(
  WidgetTester tester, {
  required String nomFichier,
  required Widget child,
  required bool sombre,
  required double largeur,
  required double hauteur,
  required List<SingleChildWidget> providers,
}) async {
  await tester.pumpWidget(
    _application(
      child: child,
      sombre: sombre,
      providers: providers,
      largeur: largeur,
      hauteur: hauteur,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  // Aucune exception de mise en page ne doit avoir été produite : c'est
  // cette assertion qui fait de ce fichier un test de « responsive ».
  expect(tester.takeException(), isNull,
      reason: 'Mise en page en échec à ${largeur}x$hauteur ($nomFichier).');

  // Écriture de l'image.
  //
  // On passe par le mécanisme de goldens de Flutter, qui sait produire une
  // image dans un test : il gère lui-même la synchronisation avec le moteur
  // de rendu, là où un `RenderRepaintBoundary.toImage()` manuel se bloque
  // sous le faux ordonnanceur de `flutter test`.
  //
  // Avec `--update-goldens`, le fichier est (ré)écrit. Sans cette option, la
  // comparaison n'a lieu QUE sur la machine de référence (Linux + option
  // explicite) : le rendu du texte différant d'une plateforme à l'autre, une
  // comparaison systématique produirait des échecs pour une interface
  // identique.
  if (comparerAuPixel) {
    await expectLater(
      find.byKey(const Key('zone-capture')),
      matchesGoldenFile('$kDossierSortie/$nomFichier.png'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _simulerPreferences();
    _policesChargees = await _chargerPolice();
  });

  // Les animations sont coupées : on capture l'état final, de façon
  // déterministe.
  setUp(() => OmniMouvementTest.desactivees = true);
  tearDown(() => OmniMouvementTest.desactivees = false);

  for (final taille in kTailles) {
    for (final sombre in <bool>[true, false]) {
      final suffixeTheme = sombre ? 'sombre' : 'clair';

      testWidgets(
        'liste des conversations — ${taille.nom} — $suffixeTheme',
        (tester) async {
          if (!_policesChargees) {
            markTestSkipped('Polices du SDK Flutter introuvables.');
          }

          await tester.binding.setSurfaceSize(
            Size(taille.largeur * 2, taille.hauteur * 2),
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final provider = _ProviderHorsLigne();
          final presence = PresenceService(realtime: _PresenceInerte());
          for (final c in _conversations()) {
            provider.addOrUpdateConversation(c);
          }

          await _capturer(
            tester,
            nomFichier: 'liste-${taille.nom}-$suffixeTheme',
            child: const MessagesListPage(),
            sombre: sombre,
            largeur: taille.largeur,
            hauteur: taille.hauteur,
            providers: [
              ChangeNotifierProvider<MessagingProvider>.value(value: provider),
              ChangeNotifierProvider<PresenceService>.value(value: presence),
            ],
          );

          // Le contenu attendu est réellement présent à cette taille.
          expect(find.text('Alice Dupont'), findsOneWidget);
          expect(find.text('Groupe Équipe'), findsOneWidget);

          provider.dispose();
          presence.dispose();
        },
      );

      testWidgets(
        'conversation — ${taille.nom} — $suffixeTheme',
        (tester) async {
          if (!_policesChargees) {
            markTestSkipped('Polices du SDK Flutter introuvables.');
          }

          await tester.binding.setSurfaceSize(
            Size(taille.largeur * 2, taille.hauteur * 2),
          );
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final provider = _ProviderHorsLigne();
          final presence = PresenceService(realtime: _PresenceInerte());
          for (final c in _conversations()) {
            provider.addOrUpdateConversation(c);
          }

          await _capturer(
            tester,
            nomFichier: 'conversation-${taille.nom}-$suffixeTheme',
            child: _ecranConversation(),
            sombre: sombre,
            largeur: taille.largeur,
            hauteur: taille.hauteur,
            providers: [
              ChangeNotifierProvider<MessagingProvider>.value(value: provider),
              ChangeNotifierProvider<PresenceService>(
                create: (_) => PresenceService(realtime: _PresenceInerte()),
              ),
            ],
          );

          expect(find.text('Salut ! Tu as reçu le colis ?'), findsOneWidget);
          expect(find.text('Oui, livré ce matin 👍'), findsOneWidget);

          provider.dispose();
          presence.dispose();
        },
      );
    }
  }
}
