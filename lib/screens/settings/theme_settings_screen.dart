import 'package:flutter/material.dart';
import '../../theme/omni_design.dart';
import '../../theme/omni_motion.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thème'),
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ListView(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apparence',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choisissez le thème de l\'application',
                      style: TextStyle(
                        color: OmniCouleurs.of(context).texteSecondaire,
                      ),
                    ),
                  ],
                ),
              ),

              // Theme Options
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                  }
                },
                title: const Text('Clair'),
                subtitle: const Text('Thème clair'),
                secondary: const Icon(Icons.light_mode),
              ),

              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                  }
                },
                title: const Text('Sombre'),
                subtitle: const Text('Thème sombre'),
                secondary: const Icon(Icons.dark_mode),
              ),

              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                  }
                },
                title: const Text('Système'),
                subtitle: const Text('Suivre les paramètres du système'),
                secondary: const Icon(Icons.settings_brightness),
              ),

              // ── Style visuel ─────────────────────────────────────────
              const Divider(height: 32),
              OmniApparitionEspacee(
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniEspace.l,
                    vertical: OmniEspace.s,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Style visuel',
                        style: OmniTypo.sousTitre.copyWith(
                          color: OmniCouleurs.of(context).texte,
                        ),
                      ),
                      const SizedBox(height: OmniEspace.xs),
                      Text(
                        'Deux identités coexistent. L’ancienne reste '
                        'disponible : si la nouvelle ne convient pas, le '
                        'retour est immédiat.',
                        style: OmniTypo.secondaire.copyWith(
                          color: OmniCouleurs.of(context).texteSecondaire,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              for (final variante in OmniVariante.values)
                OmniApparitionEspacee(
                  index: OmniVariante.values.indexOf(variante) + 1,
                  child: RadioListTile<OmniVariante>(
                    value: variante,
                    groupValue: themeProvider.variante,
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setVariante(value);
                      }
                    },
                    title: Text(variante.libelle),
                    subtitle: Text(variante.description),
                    secondary: _Pastille(variante: variante),
                  ),
                ),

              const SizedBox(height: 24),

              // Preview Card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.palette_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Aperçu',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.message,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Exemple de message',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Changement appliqué',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Info Card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Le changement de thème est immédiat dans toute l\'application',
                            style: TextStyle(
                              fontSize: 14,
                              color: OmniCouleurs.of(context).texte,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pastille d'aperçu d'une variante.
///
/// Montrer les couleurs réelles de la variante vaut mieux que les décrire :
/// le choix se fait à l'œil, pas sur un texte.
class _Pastille extends StatelessWidget {
  const _Pastille({required this.variante});

  final OmniVariante variante;

  @override
  Widget build(BuildContext context) {
    final degrade = switch (variante) {
      OmniVariante.nova => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OmniNovaPalette.cyan,
            OmniNovaPalette.indigo,
            OmniNovaPalette.magenta,
          ],
        ),
      OmniVariante.classique => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OmniPalette.cyan, OmniPalette.bleu],
        ),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: degrade,
        shape: BoxShape.circle,
        border: Border.all(
          color: OmniCouleurs.of(context).contour,
        ),
      ),
    );
  }
}
