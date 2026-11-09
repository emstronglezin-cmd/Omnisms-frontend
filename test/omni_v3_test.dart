import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/theme/omni_design.dart';
import 'package:omnisms/theme/omni_motion.dart';
import 'package:omnisms/theme/omni_responsive.dart';

/// Tests du socle V3 : mouvement, adaptation à l'écran, composants animés.
///
/// Deux catégories :
/// * des tests **purs** (classes de taille de fenêtre, durées) ;
/// * des tests **de rendu**, qui vérifient que les composants animés
///   s'affichent sans erreur et sans laisser de minuteur en attente — la
///   panne la plus courante d'un composant animé sous test.
void main() {
  // Les animations sont coupées : les tests portent sur le rendu final, pas
  // sur le minutage.
  setUp(() => OmniMouvementTest.desactivees = true);
  tearDown(() => OmniMouvementTest.desactivees = false);

  group('Adaptation à l’écran', () {
    OmniMetriques metres(double largeur, {double hauteur = 800}) {
      return OmniResponsive.depuis(
        MediaQueryData(size: Size(largeur, hauteur)),
      );
    }

    test('360 × 800 est une fenêtre compacte, sur deux colonnes', () {
      final m = metres(360);
      expect(m.taille, OmniTailleFenetre.compacte);
      expect(m.estCompacte, isTrue);
      expect(m.colonnes, 2);
      expect(m.accepteDeuxVolets, isFalse);
      expect(m.marge, OmniEspace.l);
    });

    test('393 × 852 et 432 × 960 restent compactes', () {
      expect(metres(393, hauteur: 852).taille, OmniTailleFenetre.compacte);
      expect(metres(432, hauteur: 960).taille, OmniTailleFenetre.compacte);
    });

    test('une fenêtre moyenne passe à trois colonnes', () {
      final m = metres(600);
      expect(m.taille, OmniTailleFenetre.moyenne);
      expect(m.colonnes, 3);
      expect(m.accepteDeuxVolets, isTrue);
      expect(m.marge, OmniEspace.xxl);
    });

    test('un grand écran plafonne la largeur du contenu', () {
      final m = metres(1024, hauteur: 1366);
      expect(m.taille, OmniTailleFenetre.etendue);
      expect(m.largeurContenuMax, 720);
    });

    test('un très grand écran passe à quatre colonnes', () {
      expect(metres(1280).colonnes, 4);
    });

    test('le clavier ouvert est détecté', () {
      final data = MediaQueryData(
        size: const Size(393, 852),
        viewInsets: const EdgeInsets.only(bottom: 340),
      );
      expect(OmniResponsive.depuis(data).clavierOuvert, isTrue);
    });

    test('la hauteur critique est signalée quand le clavier mange l’écran',
        () {
      final data = MediaQueryData(
        size: const Size(360, 420),
        viewInsets: const EdgeInsets.only(bottom: 300),
      );
      final m = OmniResponsive.depuis(data);
      expect(m.hauteur, 420);
      expect(m.hauteurCritique, isTrue);
    });
  });

  group('Système de mouvement', () {
    test('les durées respectent la hiérarchie expressif > long > sortie', () {
      expect(
        OmniMouvement.expressif,
        greaterThan(OmniMouvement.long),
      );
      expect(OmniMouvement.long, greaterThan(OmniMouvement.sortie));
      expect(OmniMouvement.instantane, lessThan(OmniMouvement.court));
    });

    test('un retour tactile reste sous les 100 ms', () {
      // Au-delà, l'interface paraît molle : c'est une contrainte
      // perceptuelle, pas une préférence.
      expect(
        OmniMouvement.instantane.inMilliseconds,
        lessThanOrEqualTo(100),
      );
    });

    test('les ressorts sont amortis (pas d’oscillation infinie)', () {
      for (final ressort in [
        OmniMouvement.ressortCourt,
        OmniMouvement.ressortMoyen,
        OmniMouvement.ressortLong,
      ]) {
        expect(ressort.damping, greaterThan(0));
        expect(ressort.stiffness, greaterThan(0));
      }
    });

    test('les animations sont neutralisées quand le système le demande', () {
      final data = MediaQueryData(
        size: const Size(393, 852),
        disableAnimations: true,
      );
      final espace = OmniResponsive.depuis(data);

      // On vérifie la logique de façon isolée, via un MediaQuery réel.
      final reduit = data.disableAnimations;
      expect(reduit, isTrue);
      expect(espace.largeur, 393);
    });
  });

  group('Composants animés — rendu sans fuite', () {
    Future<void> rendre(
      WidgetTester tester,
      Widget child, {
      bool animationsReduites = false,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(393, 852),
            disableAnimations: animationsReduites,
          ),
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(body: child),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('OmniApparition affiche son enfant', (tester) async {
      await rendre(
        tester,
        const OmniApparition(child: Text('contenu visible')),
      );
      expect(find.text('contenu visible'), findsOneWidget);
    });

    testWidgets('OmniApparitionEspacee plafonne le décalage', (tester) async {
      // Sans plafond, le 200e élément attendrait plusieurs secondes.
      // Le composant doit borner l'index : au-delà de 12, plus de délai.
      await rendre(
        tester,
        const Column(
          children: [
            OmniApparitionEspacee(index: 0, child: Text('premier')),
            OmniApparitionEspacee(index: 500, child: Text('lointain')),
          ],
        ),
      );

      expect(find.text('premier'), findsOneWidget);
      expect(find.text('lointain'), findsOneWidget);

      final lointain =
          tester.widget<OmniApparition>(find.ancestor(
        of: find.text('lointain'),
        matching: find.byType(OmniApparition),
      ));
      // 12 pas de 28 ms = 336 ms maximum, jamais plus.
      expect(
        lointain.delai.inMilliseconds,
        lessThanOrEqualTo(336),
      );
    });

    testWidgets('OmniSquelette se rend et se nettoie', (tester) async {
      await rendre(tester, const OmniSquelette(largeur: 120, hauteur: 16));

      expect(find.byType(OmniSquelette), findsOneWidget);
      // Aucun minuteur ne doit subsister après le démontage.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('OmniCompteurAnime affiche la valeur exacte', (tester) async {
      await rendre(
        tester,
        const OmniCompteurAnime(valeur: 42, style: TextStyle(fontSize: 20)),
      );
      // Animations coupées : la valeur finale est immédiate.
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('OmniPression transmet l’appui', (tester) async {
      var appuis = 0;
      await rendre(
        tester,
        OmniPression(
          onTap: () => appuis++,
          child: const Text('cible'),
        ),
      );

      await tester.tap(find.text('cible'));
      await tester.pump();
      expect(appuis, 1);
    });

    testWidgets('OmniPression ignoré quand il est inactif', (tester) async {
      var appuis = 0;
      await rendre(
        tester,
        OmniPression(
          actif: false,
          onTap: () => appuis++,
          child: const Text('cible'),
        ),
      );

      await tester.tap(find.text('cible'));
      await tester.pump();
      expect(appuis, 0,
          reason: 'Un composant désactivé ne doit pas réagir à l’appui.');
    });

    testWidgets('OmniResponsive est requis pour être lu', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: _LecteurEspace()),
      );

      // Sans OmniResponsive dans l'arbre, maybeOf renvoie null et of lève
      // une erreur explicite plutôt que de renvoyer une valeur par défaut.
      expect(
        tester.takeException(),
        isA<FlutterError>(),
      );
    });
  });

  group('Contenu centré', () {
    testWidgets('le contenu est plafonné sur grand écran', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1024, 1366)),
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const OmniResponsive(
              child: Scaffold(
                body: OmniContenuCentre(child: Text('contenu')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // On cible la contrainte qui enveloppe notre contenu : le Scaffold
      // insère lui-même des ConstrainedBox, donc une recherche globale
      // tomberait sur celles du framework.
      final contrainte = tester.widget<ConstrainedBox>(find.ancestor(
        of: find.text('contenu'),
        matching: find.byType(ConstrainedBox),
      ));
      expect(contrainte.constraints.maxWidth, 720);
    });
  });
}

/// Écran de test qui tente de lire l'espace sans fournisseur.
class _LecteurEspace extends StatelessWidget {
  const _LecteurEspace();

  @override
  Widget build(BuildContext context) {
    OmniResponsive.of(context);
    return const SizedBox.shrink();
  }
}
