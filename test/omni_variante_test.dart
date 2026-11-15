import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/providers/theme_provider.dart';
import 'package:omnisms/theme/omni_design.dart';
import 'package:omnisms/theme/omni_motion.dart';
import 'package:omnisms/theme/omni_theme.dart';

/// Tests du système à deux identités visuelles.
///
/// Le point critique n'est pas que la nouvelle variante existe : c'est que
/// l'ancienne **reste intacte et sélectionnable**. Un changement d'identité
/// qu'on ne peut pas annuler n'est pas un choix, c'est une contrainte.
void main() {
  setUp(() => OmniMouvementTest.desactivees = true);
  tearDown(() => OmniMouvementTest.desactivees = false);

  Future<OmniCouleurs> resoudre(WidgetTester tester, ThemeData theme) async {
    late OmniCouleurs obtenues;
    // Sans cette remise à zéro, Flutter réutilise l'arbre d'éléments
    // précédent quand les types de widgets se correspondent : la seconde
    // mesure renverrait alors la palette de la première.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              obtenues = OmniCouleurs.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return obtenues;
  }

  group('Variante classique — l’identité d’origine', () {
    testWidgets('reste le défaut', (tester) async {
      final c = await resoudre(tester, OmniTheme.sombre());
      expect(c.estNova, isFalse,
          reason: 'La variante par défaut doit rester l’identité d’origine.');
    });

    testWidgets('conserve ses couleurs historiques', (tester) async {
      final c = await resoudre(tester, OmniTheme.sombre());

      // Ces valeurs sont l'identité Omni d'origine. Si un de ces tests
      // échoue, c'est que l'ancienne identité a été altérée — ce qui
      // retirerait précisément la possibilité de revenir en arrière.
      expect(c.fond, const Color(0xFF08090F));
      expect(c.accent, OmniPalette.cyan);
      expect(c.texte, const Color(0xFFE9EEF7));
    });

    testWidgets('son dégradé reste celui d’accent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OmniTheme.sombre(),
          home: const Scaffold(body: SizedBox()),
        ),
      );
      final jetons = OmniJetons(
        couleurs: OmniCouleurs.sombre(),
        variante: OmniVariante.classique,
      );
      expect(jetons.degradeAurore, isA<LinearGradient>());
      expect(jetons.estNova, isFalse);
    });
  });

  group('Variante Nova', () {
    testWidgets('produit une palette différente', (tester) async {
      final classique = await resoudre(tester, OmniTheme.sombre());
      final nova = await resoudre(tester, OmniTheme.novaSombre());

      expect(nova.estNova, isTrue);
      expect(nova.fond, isNot(classique.fond),
          reason: 'Une variante qui ne change rien n’est pas une variante.');
      expect(nova.accent, isNot(classique.accent));
    });

    testWidgets('est distincte en thème clair aussi', (tester) async {
      final classique = await resoudre(tester, OmniTheme.clair());
      final nova = await resoudre(tester, OmniTheme.novaClair());

      expect(nova.fond, isNot(classique.fond));
      expect(nova.accent, isNot(classique.accent));
    });

    testWidgets('conserve la même structure de jetons', (tester) async {
      final nova = await resoudre(tester, OmniTheme.novaSombre());

      // La structure doit être complète : un jeton manquant ferait planter
      // ou rendre un écran illisible. C'est ce qui permet à tous les écrans
      // de fonctionner dans les deux variantes sans modification.
      for (final couleur in [
        nova.fond,
        nova.fondSecondaire,
        nova.surface,
        nova.surfaceVariante,
        nova.contour,
        nova.texte,
        nova.texteSecondaire,
        nova.texteEstompe,
        nova.accent,
        nova.accentSecondaire,
        nova.surAccent,
        nova.bulleSortante,
        nova.bulleSortanteTexte,
        nova.bulleEntrante,
        nova.bulleEntranteTexte,
      ]) {
        expect(couleur, isA<Color>());
      }
    });
  });

  group('Bascule entre variantes', () {
    testWidgets('les deux thèmes portent leurs jetons', (tester) async {
      final sombre = OmniTheme.sombre();
      final novaSombre = OmniTheme.novaSombre();

      final j1 = sombre.extension<OmniJetons>();
      final j2 = novaSombre.extension<OmniJetons>();

      expect(j1, isNotNull, reason: 'Sans jetons, l’écran n’a pas de palette.');
      expect(j2, isNotNull);
      expect(j1!.variante, OmniVariante.classique);
      expect(j2!.variante, OmniVariante.nova);
    });

    test('le fournisseur démarre sur l’identité d’origine', () {
      // Sans lecture de préférences, le défaut doit rester « classique ».
      final fournisseur = ThemeProvider();
      expect(fournisseur.variante, OmniVariante.classique);
    });
  });
}
