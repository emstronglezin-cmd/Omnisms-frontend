import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/theme/omni_design.dart';
import 'package:omnisms/theme/omni_motion.dart';
import 'package:omnisms/theme/omni_theme.dart';
import 'package:omnisms/widgets/common/etats_v3.dart';

/// Captures des états d'interface V3 aux tailles imposées.
///
/// Deux raisons de capturer ces états-là :
/// 1. Ce sont des écrans à part entière — l'utilisateur les voit souvent,
///    et peu de projets les testent visuellement.
/// 2. Ce sont les plus exposés au débordement : un état vide trop haut sur
///    un petit écran (ou clavier ouvert) devient un écran mort.
///
/// Les comparaisons au pixel sont réservées à Linux, la plateforme de
/// référence, et ne s'exécutent que si `OMNI_COMPARER_CAPTURES=1` : le
/// rendu des polices diffère d'une plateforme à l'autre.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final comparerAuPixel =
      Platform.isLinux && Platform.environment['OMNI_COMPARER_CAPTURES'] == '1';

  setUpAll(() {
    // Une capture doit montrer l'ÉTAT FINAL d'un écran, pas une image
    // saisie au milieu d'une animation d'entrée.
    OmniMouvementTest.desactivees = true;
  });

  /// Tailles imposées, plus un format tablette/pliable.
  const tailles = <String, Size>{
    '360x800': Size(360, 800),
    '393x852': Size(393, 852),
    '432x960': Size(432, 960),
    'pliable': Size(768, 1024),
  };

  Future<void> rendre(
    WidgetTester tester,
    Widget contenu, {
    required Size taille,
    bool sombre = true,
  }) async {
    tester.view.physicalSize = taille * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: taille),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sombre ? OmniTheme.sombre() : OmniTheme.clair(),
          home: Scaffold(body: SizedBox.expand(child: contenu)),
        ),
      ),
    );
    await tester.pump();
  }

  group('État vide aux tailles imposées', () {
    for (final entree in tailles.entries) {
      testWidgets(entree.key, (tester) async {
        await rendre(
          tester,
          OmniEtatVide(
            icone: Icons.groups_rounded,
            titre: 'Aucun groupe',
            message:
                'Créez un groupe pour échanger à plusieurs avec vos contacts.',
            libelleAction: 'Créer un groupe',
            onAction: () {},
          ),
          taille: entree.value,
        );

        // Le rendu est vérifié partout : c'est ce qui garantit l'absence
        // de débordement, y compris sur les plateformes où la comparaison
        // au pixel est désactivée.
        expect(tester.takeException(), isNull,
            reason: 'Débordement dans l’état vide à ${entree.key}.');
        expect(find.text('Aucun groupe'), findsOneWidget);
        expect(find.text('Créer un groupe'), findsOneWidget);

        if (comparerAuPixel) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/etats/vide_${entree.key}.png'),
          );
        }
      });
    }
  });

  group('État d’erreur', () {
    testWidgets('360x800', (tester) async {
      await rendre(
        tester,
        OmniEtatErreur(
          message: 'Connexion impossible. Vérifiez votre réseau.',
          onReessayer: () {},
        ),
        taille: const Size(360, 800),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Connexion impossible. Vérifiez votre réseau.'),
          findsOneWidget);

      if (comparerAuPixel) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/etats/erreur_360x800.png'),
        );
      }
    });

    testWidgets('thème clair — 393x852', (tester) async {
      await rendre(
        tester,
        OmniEtatErreur(
          message: 'Connexion impossible. Vérifiez votre réseau.',
          onReessayer: () {},
        ),
        taille: const Size(393, 852),
        sombre: false,
      );

      expect(tester.takeException(), isNull);

      if (comparerAuPixel) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/etats/erreur_clair_393x852.png'),
        );
      }
    });
  });

  group('Chargement', () {
    testWidgets('360x800', (tester) async {
      await rendre(
        tester,
        const OmniEtatChargement(nombreLignes: 6),
        taille: const Size(360, 800),
      );

      expect(tester.takeException(), isNull);
      // Six lignes : chacune affiche un avatar et deux barres de texte.
      expect(find.byType(OmniSquelette), findsNWidgets(18));

      if (comparerAuPixel) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/etats/chargement_360x800.png'),
        );
      }
    });
  });
}
