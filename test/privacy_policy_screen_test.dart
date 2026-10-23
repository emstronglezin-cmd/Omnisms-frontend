import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/screens/legal/privacy_content.dart';
import 'package:omnisms/screens/legal/privacy_policy_screen.dart';

/// Vérifie que la page /privacy existe réellement, qu'elle est lisible et
/// qu'elle N'INVENTE aucune information légale (pas d'e-mail, pas de durée de
/// conservation fantaisiste, pas de chiffrement de bout en bout).
void main() {
  Widget buildScreen({double width = 390, double height = 844}) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: const MaterialApp(
        locale: Locale('fr'),
        home: PrivacyPolicyScreen(),
      ),
    );
  }

  group('Politique de confidentialité — rendu', () {
    testWidgets('la page s’affiche avec son titre et ses sections',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Politique de confidentialité'), findsWidgets);
      expect(find.text('Dernière mise à jour : 23 octobre 2026'),
          findsOneWidget);

      // La liste est construite paresseusement : on fait défiler jusqu'à
      // chaque section avant de l'affirmer présente.
      final scrollable = find.byType(Scrollable).first;
      for (final title in const [
        'Données que nous traitons',
        'Pourquoi nous les traitons',
        'À qui vos données sont transmises',
        'Durée de conservation',
        'Sécurité',
        'Vos droits',
        'Suppression du compte',
      ]) {
        await tester.scrollUntilVisible(
          find.text(title),
          400,
          scrollable: scrollable,
        );
        expect(find.text(title), findsOneWidget, reason: 'section $title');
      }
    });

    testWidgets('aucun débordement en mobile (390 dp) ni en desktop (1280 dp)',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(buildScreen(width: 1280, height: 900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('la page est accessible sans session (aucun provider requis)',
        (tester) async {
      // Aucun Provider n'est fourni : la page doit se construire seule.
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Contenu — aucune information inventée', () {
    final content = PrivacyContentFr();

    String flatten() {
      final buffer = StringBuffer();
      for (final section in content.sections) {
        buffer.writeln(section.title);
        for (final block in section.blocks) {
          buffer.writeln(block.text);
          for (final item in block.items ?? const <String>[]) {
            buffer.writeln(item);
          }
        }
      }
      return buffer.toString();
    }

    test('aucune adresse e-mail inventée', () {
      expect(RegExp(r'[\w.+-]+@[\w-]+\.[a-z]{2,}').hasMatch(flatten()), isFalse);
    });

    test('aucun chiffrement de bout en bout promis', () {
      final text = flatten().toLowerCase();
      expect(text, isNot(contains('chiffré de bout en bout'.toLowerCase()
          .replaceFirst('chiffré', 'chiffr'))));
      expect(text, contains('ne sont pas chiffrés de bout en bout'));
    });

    test('aucune promesse de non-partage absolu', () {
      final text = flatten().toLowerCase();
      // Formulations affirmatives interdites (la page doit dire le contraire
      // quand c'est le cas).
      expect(
        RegExp(r'ne sont jamais (partagé|transmis|divulgué)')
            .hasMatch(text),
        isFalse,
      );
      expect(
        RegExp(r'(aucune donnée|vos données) n.?est (jamais|pas) partagée')
            .hasMatch(text),
        isFalse,
      );
      // … et l'aveu explicite est bien présent.
      expect(text, contains('impossible de promettre'));
      expect(text, contains('ne sont pas chiffrés de bout en bout'));
    });

    test('les tiers réels sont listés', () {
      final text = flatten();
      for (final tier in const ['Google', 'Infobip', 'Firebase', 'Render']) {
        expect(text, contains(tier), reason: 'tiers $tier');
      }
    });

    test('les permissions demandées sont expliquées', () {
      final text = flatten();
      for (final perm in const ['Contacts', 'Microphone', 'Notifications']) {
        expect(text, contains(perm), reason: 'permission $perm');
      }
    });

    test('la suppression de compte décrit la procédure réelle', () {
      final text = flatten();
      expect(text, contains('Supprimer mon compte'));
      expect(text, contains('30 jours'));
    });

    test('les emplacements à compléter sont explicites', () {
      final placeholders = content.sections
          .expand((s) => s.blocks)
          .where((b) => b.kind == PrivacyBlockKind.placeholder)
          .toList();
      expect(placeholders.length, greaterThanOrEqualTo(6));
      for (final p in placeholders) {
        expect(p.text.toUpperCase(), contains('COMPLÉTER'));
      }
    });

    test('la structure est prête pour une autre langue', () {
      expect(privacyContentFor(const Locale('fr')), isA<PrivacyContentFr>());
      // Langue inconnue → français par défaut, sans erreur.
      expect(privacyContentFor(const Locale('de')), isA<PrivacyContent>());
    });
  });
}
