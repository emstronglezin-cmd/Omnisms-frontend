import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/widgets/auth/google_sign_in_button.dart';

/// Tests de PRÉSENTATION du bouton Google.
/// Le flux OAuth (ouverture du navigateur, deep link, échange du code) n'est
/// volontairement pas touché : seul le rendu est vérifié.
void main() {
  Widget buildButton({
    required VoidCallback onPressed,
    bool isLoading = false,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: GoogleSignInButton(
            onPressed: onPressed,
            isLoading: isLoading,
            enabled: enabled,
          ),
        ),
      ),
    );
  }

  group('GoogleSignInButton — rendu', () {
    testWidgets('affiche le libellé et un bouton de taille standard',
        (tester) async {
      await tester.pumpWidget(buildButton(onPressed: () {}));

      expect(find.text('Continuer avec Google'), findsOneWidget);

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      final box = tester.renderObject<RenderBox>(
        find.ancestor(
          of: find.byType(OutlinedButton),
          matching: find.byType(SizedBox),
        ),
      );
      // Hauteur identique au bouton principal de l'app (52 dp).
      expect(box.size.height, 52);
      expect(button.enabled, isTrue);
    });

    testWidgets('le bouton est accessible (sémantique + libellé)',
        (tester) async {
      await tester.pumpWidget(buildButton(onPressed: () {}));

      final data = tester
          .getSemantics(find.byType(OutlinedButton))
          .getSemanticsData();
      expect(data.label, 'Continuer avec Google');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(data.hasFlag(SemanticsFlag.isEnabled), isTrue);
    });

    testWidgets('l’appel déclenche le callback (aucune auth simulée)',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(buildButton(onPressed: () => tapped++));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

    testWidgets('état de chargement : indicateur, bouton désactivé, libellé',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
          buildButton(onPressed: () => tapped++, isLoading: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Le libellé reste affiché : pas de saut de mise en page.
      expect(find.text('Continuer avec Google'), findsOneWidget);

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.enabled, isFalse);

      // Sémantique : le bouton se déclare désactivé aux lecteurs d'écran.
      final data = tester
          .getSemantics(find.byType(OutlinedButton))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isEnabled), isFalse);

      // Pas de pumpAndSettle : l'indicateur de chargement anime en continu.
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();
      expect(tapped, 0, reason: 'pas de double lancement du flux OAuth');
    });

    testWidgets('désactivé par l’appelant : aucun appel', (tester) async {
      var tapped = 0;
      await tester
          .pumpWidget(buildButton(onPressed: () => tapped++, enabled: false));

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.enabled, isFalse);

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(tapped, 0);
    });

    testWidgets('le bouton ne provoque pas de débordement (petit écran)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildButton(onPressed: () {}));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
