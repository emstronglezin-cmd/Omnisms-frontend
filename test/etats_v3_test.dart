import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/theme/omni_design.dart';
import 'package:omnisms/theme/omni_motion.dart';
import 'package:omnisms/widgets/common/etats_v3.dart';

/// Tests des états V3 : vide, erreur, chargement, confirmation.
///
/// Ces états sont les moments où l'utilisateur décide si l'application est
/// finie ou abandonnée. Ils doivent donc être testés comme des écrans à part
/// entière, et pas seulement « ne pas planter ».
void main() {
  setUp(() => OmniMouvementTest.desactivees = true);
  tearDown(() => OmniMouvementTest.desactivees = false);

  Future<void> rendre(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: SizedBox.expand(child: child)),
      ),
    );
    await tester.pump();
  }

  group('État vide', () {
    testWidgets('affiche le titre, le message et l’action', (tester) async {
      await rendre(
        tester,
        OmniEtatVide(
          icone: Icons.groups_rounded,
          titre: 'Aucun groupe',
          message: 'Créez votre premier groupe',
          libelleAction: 'Créer un groupe',
          onAction: () {},
        ),
      );

      expect(find.text('Aucun groupe'), findsOneWidget);
      expect(find.text('Créez votre premier groupe'), findsOneWidget);
      expect(find.text('Créer un groupe'), findsOneWidget);
    });

    testWidgets('l’action est bien déclenchée par l’appui', (tester) async {
      var appels = 0;
      await rendre(
        tester,
        OmniEtatVide(
          icone: Icons.groups_rounded,
          titre: 'Aucun groupe',
          libelleAction: 'Créer un groupe',
          onAction: () => appels++,
        ),
      );

      await tester.tap(find.text('Créer un groupe'));
      await tester.pump();
      expect(appels, 1);
    });

    testWidgets('sans action, aucun bouton n’est affiché', (tester) async {
      await rendre(
        tester,
        const OmniEtatVide(
          icone: Icons.inbox_rounded,
          titre: 'Rien ici',
        ),
      );

      expect(find.text('Rien ici'), findsOneWidget);
      // Pas de bouton orphelin : l'absence d'action se traduit par une
      // interface plus courte, pas par un bouton inerte.
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('tient sur un petit écran sans déborder', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(360, 480)),
          child: MaterialApp(
            home: Scaffold(
              body: OmniEtatVide(
                icone: Icons.groups_rounded,
                titre: 'Aucun groupe',
                message: 'Créez un groupe pour échanger à plusieurs.',
                libelleAction: 'Créer un groupe',
                onAction: null,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Une exception de débordement aurait été enregistrée ici.
      expect(tester.takeException(), isNull);
      expect(find.text('Aucun groupe'), findsOneWidget);
    });
  });

  group('État d’erreur', () {
    testWidgets('affiche le message et le bouton de reprise', (tester) async {
      var reprises = 0;
      await rendre(
        tester,
        OmniEtatErreur(
          message: 'Connexion impossible.',
          onReessayer: () => reprises++,
        ),
      );

      expect(find.text('Connexion impossible.'), findsOneWidget);

      await tester.tap(find.text(OmniEtats.reessayer));
      await tester.pump();
      expect(reprises, 1);
    });
  });

  group('Chargement', () {
    testWidgets('dessine la forme du contenu, pas un cercle seul',
        (tester) async {
      await rendre(tester, const OmniEtatChargement(nombreLignes: 4));

      // Un squelette est annoncé par sa forme : quatre lignes, chacune
      // composée d'un avatar et de deux barres de texte.
      expect(find.byType(OmniSquelette), findsNWidgets(12));
    });
  });

  group('Confirmation de succès', () {
    testWidgets('affiche un bandeau flottant avec le message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(body: _Declencheur()),
        ),
      );

      await tester.tap(find.text('déclencher'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Profil enregistré'), findsOneWidget);
    });
  });
}

/// Écran minimal qui déclenche une confirmation de succès.
class _Declencheur extends StatelessWidget {
  const _Declencheur();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => afficherSucces(context, 'Profil enregistré'),
        child: const Text('déclencher'),
      ),
    );
  }
}
