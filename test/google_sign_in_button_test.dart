import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:omnisms/widgets/auth/google_sign_in_button.dart';

/// Bouton « Continuer avec Google » : le logo doit être l'asset officiel
/// (4 couleurs), et non une lettre « G » ou un dessin approximatif.
void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    bool isLoading = false,
    bool enabled = true,
    VoidCallback? onPressed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleSignInButton(
            isLoading: isLoading,
            enabled: enabled,
            onPressed: onPressed ?? () {},
          ),
        ),
      ),
    );
    // pump() et non pumpAndSettle() : l'indicateur de chargement (quand il
    // est affiché) anime indéfiniment la scène.
    await tester.pump();
  }

  testWidgets('affiche le libellé exact « Continuer avec Google »',
      (WidgetTester tester) async {
    await pumpButton(tester);

    expect(find.text('Continuer avec Google'), findsOneWidget);
  });

  testWidgets('affiche le logo Google officiel (asset SVG)',
      (WidgetTester tester) async {
    await pumpButton(tester);

    // Le logo est un SvgPicture chargé depuis l'asset officiel.
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('aucun « G » texte : pas de logo approximatif',
      (WidgetTester tester) async {
    await pumpButton(tester);

    // L'ancienne implémentation dessinait un cercle bleu contenant « G ».
    expect(find.text('G'), findsNothing);
  });

  testWidgets('accessible : étiquette et état activé exposés',
      (WidgetTester tester) async {
    await pumpButton(tester);

    final semantics = tester.getSemantics(find.byType(GoogleSignInButton));
    expect(semantics.label, contains('Continuer avec Google'));
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('pendant le flux : bouton désactivé + indicateur de chargement',
      (WidgetTester tester) async {
    await pumpButton(tester, isLoading: true);

    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
      reason: 'un double-clic ouvrirait deux fois le navigateur',
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsNothing);
  });

  testWidgets('déclenche l\'action au tap', (WidgetTester tester) async {
    var calls = 0;
    await pumpButton(tester, onPressed: () => calls++);

    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pump();

    expect(calls, 1);
  });
}
