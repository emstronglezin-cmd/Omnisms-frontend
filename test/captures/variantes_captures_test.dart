import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/theme/omni_design.dart';
import 'package:omnisms/theme/omni_motion.dart';
import 'package:omnisms/theme/omni_theme.dart';
import 'package:omnisms/widgets/chat/modern_message_input.dart';

/// Captures comparatives des deux identités visuelles.
///
/// Les deux variantes sont capturées **sur le même écran, au même instant**.
/// C'est la seule façon de comparer honnêtement : décrire deux palettes ne
/// permet pas de choisir, les voir côte à côte si.
///
/// Comparaison au pixel réservée à Linux avec `OMNI_COMPARER_CAPTURES=1`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final comparer = Platform.isLinux &&
      Platform.environment['OMNI_COMPARER_CAPTURES'] == '1';

  setUpAll(() => OmniMouvementTest.desactivees = true);

  Future<void> capturer(
    WidgetTester tester, {
    required String nom,
    required ThemeData theme,
  }) async {
    tester.view.physicalSize = const Size(411, 260) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(411, 260)),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                // Bandeau : montre le fond, la surface et l'accent.
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: theme.extension<OmniJetons>()!.degradeAurore,
                      borderRadius: OmniRayon.carte,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'OmniSMS',
                        style: OmniTypo.titre.copyWith(
                          color: theme.extension<OmniJetons>()!.couleurs
                              .bulleSortanteTexte,
                        ),
                      ),
                    ),
                  ),
                ),
                // Barre de saisie : montre surface, contour et bouton.
                ModernMessageInput(
                  onSendMessage: (_) {},
                  onStartRecording: () {},
                  onAttachment: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'Débordement dans la capture $nom.');

    if (comparer) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/variantes/$nom.png'),
      );
    }
  }

  testWidgets('variante classique', (tester) async {
    await capturer(tester, nom: 'variante_classique', theme: OmniTheme.sombre());
  });

  testWidgets('variante nova', (tester) async {
    await capturer(
      tester,
      nom: 'variante_nova',
      theme: OmniTheme.novaSombre(),
    );
  });
}
