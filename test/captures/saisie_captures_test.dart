import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/theme/omni_motion.dart';
import 'package:omnisms/theme/omni_theme.dart';
import 'package:omnisms/widgets/chat/modern_message_input.dart';

/// Captures de la barre de saisie dans ses deux états.
///
/// L'objet de ces captures est le bouton droit : il est **micro** quand le
/// champ est vide et **envoyer** dès qu'un texte est saisi. Montrer les deux
/// états permet de vérifier que le changement de rôle est visible — c'est
/// tout l'intérêt de l'animation qui les relie.
///
/// Les comparaisons au pixel sont réservées à Linux avec
/// `OMNI_COMPARER_CAPTURES=1`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final comparer = Platform.isLinux &&
      Platform.environment['OMNI_COMPARER_CAPTURES'] == '1';

  setUpAll(() => OmniMouvementTest.desactivees = true);

  Future<void> rendre(
    WidgetTester tester, {
    required String texteInitial,
    required String nom,
    bool sombre = true,
  }) async {
    tester.view.physicalSize = const Size(411, 120) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final controleur = TextEditingController(text: texteInitial);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(411, 120)),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: sombre ? OmniTheme.sombre() : OmniTheme.clair(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ModernMessageInput(
                // Le contrôleur interne est créé par le widget ; on injecte
                // le texte via `enterText` après le premier rendu.
                onSendMessage: (_) {},
                onStartRecording: () {},
                onAttachment: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    if (texteInitial.isNotEmpty) {
      await tester.enterText(find.byType(TextField), texteInitial);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    }
    controleur.dispose();

    expect(tester.takeException(), isNull,
        reason: 'Débordement dans la barre de saisie ($nom).');

    if (comparer) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/saisie/$nom.png'),
      );
    }
  }

  testWidgets('état micro — champ vide', (tester) async {
    await rendre(tester, texteInitial: '', nom: 'saisie_micro');

    // Le bouton propose la dictée : c'est l'icône micro qui est affichée.
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
  });

  testWidgets('état envoyer — texte saisi', (tester) async {
    await rendre(tester, texteInitial: 'Bonjour', nom: 'saisie_envoyer');

    // Le rôle a changé, et l'icône avec lui : c'est la garantie que
    // l'utilisateur voit la fonction du bouton avant d'appuyer.
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
  });

  testWidgets('la bascule se fait réellement', (tester) async {
    await rendre(tester, texteInitial: '', nom: 'saisie_bascule');

    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bonjour');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}
