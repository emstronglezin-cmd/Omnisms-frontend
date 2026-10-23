import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/widgets/common/app_error_widget.dart';

/// Vérifie qu'aucune sortie technique (exception, JSON, pile d'appels) n'est
/// rendue dans l'interface — c'était l'écran rouge observé en test.
class _ThrowingWidget extends StatelessWidget {
  const _ThrowingWidget();

  @override
  Widget build(BuildContext context) {
    throw StateError('Something went very wrong internally');
  }
}

void main() {
  setUp(() {
    // Même installation que `main.dart` (_installErrorHandlers).
    ErrorWidget.builder = buildErrorWidget;
  });

  tearDown(() {
    // Retour au comportement par défaut du framework entre les tests.
    ErrorWidget.builder = (details) => ErrorWidget(details.exception);
  });

  testWidgets('une exception de build affiche une vue propre, pas l’écran rouge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: const Scaffold(body: _ThrowingWidget())),
    );
    // L'exception est capturée par le framework…
    expect(tester.takeException(), isNotNull);
    await tester.pump();

    // …et remplacée par notre vue.
    expect(find.byType(AppErrorView), findsOneWidget);

    // Aucun texte technique dans l'arbre.
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' | ');
    expect(texts, isNot(contains('StateError')));
    expect(texts, isNot(contains('#0')));
    expect(texts, isNot(contains('went very wrong internally')));
  });

  testWidgets('la vue d’erreur propose un message lisible', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: buildErrorWidget(FlutterErrorDetails(
          exception: 'SocketException: Failed host lookup',
        )),
      ),
    ));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('Pas de connexion réseau'), findsOneWidget);
    expect(find.textContaining('SocketException'), findsNothing);
  });

  testWidgets('le bouton « Réessayer » déclenche l’action', (tester) async {
    var retried = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppErrorView(
          message: 'Chargement impossible',
          onRetry: () => retried++,
        ),
      ),
    ));

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(retried, 1);
  });

  testWidgets('la version compacte tient dans une tuile', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 80,
          child: AppErrorView(message: 'Erreur', compact: true),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Erreur'), findsOneWidget);
  });
}
