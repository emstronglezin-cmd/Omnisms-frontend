import 'dart:async' show Completer;
import 'package:flutter/material.dart';

import '../../utils/user_messages.dart';

/// Vue d'erreur propre, aux couleurs de l'application.
///
/// Remplace l'écran rouge de Flutter (qui affichait une exception brute et
/// parfois une pile d'appels à l'utilisateur — cf. la vidéo de test).
///
/// Ce que ce widget fait :
///   - affiche un message court et compréhensible ;
///   - propose un bouton « Réessayer » quand un rechargement est possible.
///
/// Ce qu'il ne fait PAS :
///   - il ne masque rien : le détail technique est journalisé par
///     `main.dart` (FlutterError.onError / PlatformDispatcher.onError) ;
///   - il ne désactive aucun contrôle de sécurité ;
///   - il n'affiche jamais de JSON, de trace ni de corps de réponse HTTP.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  /// Message lisible (déjà traduit par `userMessage`).
  final String? message;

  /// Action de reprise (ex. recharger l'écran).
  final VoidCallback? onRetry;

  /// Version réduite (utilisée à l'intérieur d'une liste ou d'une tuile).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = message ?? userMessage(null);

    final content = <Widget>[
      Icon(
        Icons.error_outline,
        size: compact ? 24 : 48,
        color: theme.colorScheme.error,
      ),
      SizedBox(height: compact ? 8 : 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: (compact
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.titleMedium)
              ?.copyWith(color: theme.colorScheme.onSurface),
        ),
      ),
      if (!compact) ...[
        const SizedBox(height: 8),
        Text(
          "Le détail technique est enregistré dans les journaux de "
          "l'application.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
      if (onRetry != null) ...[
        SizedBox(height: compact ? 8 : 20),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      ],
    ];

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: content,
        ),
      ),
    );
  }

}

/// Construit la vue affichée à la place de l'écran rouge Flutter.
///
/// Volontairement autonome (Directionality fourni) : l'erreur peut survenir
/// n'importe où dans l'arbre, y compris là où aucun Material n'est présent.
Widget buildErrorWidget(FlutterErrorDetails details) {
  final message = userMessage(details.exception);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: AppErrorView(message: message),
    ),
  );
}

/// Exécute [action] et renvoie `true` si elle réussit — utilisé par les
/// boutons « Réessayer » pour relancer un chargement sans bloquer l'UI.
Future<bool> runSafely(Future<void> Function() action) async {
  final completer = Completer<bool>();
  try {
    await action();
    if (!completer.isCompleted) completer.complete(true);
  } catch (e) {
    if (!completer.isCompleted) completer.complete(false);
  }
  return completer.future;
}
