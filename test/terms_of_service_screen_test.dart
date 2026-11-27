import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/screens/legal/privacy_content.dart'
    show PrivacyBlockKind;
import 'package:omnisms/screens/legal/terms_content.dart';
import 'package:omnisms/screens/legal/terms_of_service_screen.dart';

/// Vérifie que la page « Conditions générales d'utilisation » existe
/// réellement, qu'elle est lisible et qu'elle N'INVENTE aucune mention
/// juridique : identité de l'éditeur, tarifs contractuels, responsabilité,
/// droit applicable et juridictions restent des emplacements explicites
/// « À COMPLÉTER ».
void main() {
  Widget buildScreen({double width = 390, double height = 844}) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: const MaterialApp(
        locale: Locale('fr'),
        home: TermsOfServiceScreen(),
      ),
    );
  }

  group("Conditions générales d'utilisation — rendu", () {
    testWidgets('la page s’affiche avec son titre et ses sections',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text("Conditions générales d'utilisation"), findsWidgets);
      expect(find.text('Dernière mise à jour : 11 octobre 2026'), findsOneWidget);

      for (final title in const [
        'Objet de ce document',
        'Éditeur du service',
        'Le service',
        'Compte et accès',
        'Suppression du compte',
        'Abonnement Premium',
        'Limites techniques connues',
        'Données personnelles',
        'Propriété intellectuelle',
        'Droit applicable et litiges',
        'Modifications de ces conditions',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 300,
            scrollable: find.byType(Scrollable).first);
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
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      expect(find.byType(TermsOfServiceScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Contenu — aucune mention juridique inventée', () {
    final content = TermsContentFr();

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
      expect(
        RegExp(r'[\w.+-]+@[\w-]+\.[a-z]{2,}').hasMatch(flatten()),
        isFalse,
      );
    });

    test("aucune identité légale ni raison sociale inventée", () {
      final text = flatten().toLowerCase();
      for (final interdit in const [
        'sarl',
        'sas',
        'numéro rcs',
        'registre du commerce',
        'capital social',
      ]) {
        expect(text, isNot(contains(interdit)), reason: 'mention $interdit');
      }
    });

    test('aucun droit applicable ni juridiction inventé', () {
      final text = flatten().toLowerCase();
      // La section existe, mais son contenu reste à rédiger par l'éditeur.
      expect(text, contains('droit applicable'));
      expect(
        RegExp(r'(loi|droit) (burkinab|français|française|américain)')
            .hasMatch(text),
        isFalse,
      );
      expect(text, isNot(contains('tribunal de commerce')));
    });

    test('aucune promesse de disponibilité ou de SLA inventée', () {
      final text = flatten().toLowerCase();
      expect(text, isNot(contains('99,9')));
      expect(text, isNot(contains('garantie de disponibilité')));
      expect(text, contains("n'est pas encore active"));
    });

    test('le montant affiché correspond au code de l’application', () {
      // lib/screens/subscription_screen.dart envoie amount: 2000, currency: XOF.
      final text = flatten();
      expect(text, contains('2 000 FCFA'));
      expect(text, contains('XOF'));
    });

    test('la redirection de paiement n’est jamais présentée comme une preuve',
        () {
      final text = flatten().toLowerCase();
      expect(text, contains('ne vaut pas activation'));
      expect(text, contains('annulé, refusé ou expiré'));
    });

    test('les emplacements à compléter sont explicites', () {
      final placeholders = content.sections
          .expand((s) => s.blocks)
          .where((b) => b.kind == PrivacyBlockKind.placeholder)
          .toList();
      // Identité de l'éditeur, hébergeur, usage abusif, tarifs, responsabilité,
      // propriété intellectuelle, droit applicable, information des
      // modifications : huit emplacements, tous explicites.
      expect(placeholders.length, greaterThanOrEqualTo(8));
      for (final p in placeholders) {
        expect(p.text.toUpperCase(), contains('COMPLÉTER'));
      }
    });

    test('la structure est prête pour une autre langue', () {
      expect(termsContentFor(const Locale('fr')), isA<TermsContentFr>());
      // Langue inconnue → français par défaut, sans erreur.
      expect(termsContentFor(const Locale('de')), isA<TermsContent>());
    });
  });
}
