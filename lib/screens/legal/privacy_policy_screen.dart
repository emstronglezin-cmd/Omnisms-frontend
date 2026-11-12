import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../theme/omni_design.dart';

import 'privacy_content.dart';

/// Page « Politique de confidentialité » — publique, sans connexion requise.
///
/// Accessible :
///   - depuis l'application : Connexion, Inscription, Paramètres ;
///   - depuis le web : route publique `/privacy` (même adresse que la PWA) ;
///   - via la route nommée `/privacy` de `MaterialApp` (main.dart).
///
/// Responsive : largeur maximale de 820 dp, marges adaptées (téléphone /
/// tablette / desktop). Le texte est sélectionnable (utile pour copier une
/// section ou la faire traduire par le lecteur).
///
/// Le contenu est entièrement externalisé dans [PrivacyContent] pour
/// permettre l'ajout d'autres langues sans toucher à la mise en page.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key, this.showAppBar = true});

  /// Mettre `false` pour une intégration dans un autre écran (ex. onglet).
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final content = privacyContentFor(Localizations.localeOf(context));
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final padding = EdgeInsets.symmetric(
      horizontal: isWide ? 32 : 16,
      vertical: isWide ? 32 : 20,
    );

    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SelectionArea(
          child: ListView(
            padding: padding,
            children: [
              _Header(content: content),
              const SizedBox(height: 16),
              for (final section in content.sections) ...[
                _SectionView(section: section),
                const SizedBox(height: 24),
              ],
              const _Footer(),
            ],
          ),
        ),
      ),
    );

    if (!showAppBar) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Politique de confidentialité'),
        // Sur le web, un bouton de retour sans historique utile ramènerait à
        // une page vide : on le masque (la navigation du navigateur suffit).
        automaticallyImplyLeading: !kIsWeb,
      ),
      body: SafeArea(child: body),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.content});

  final PrivacyContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Politique de confidentialité',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Dernière mise à jour : ${content.updatedOn}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 12),
        // Encadré honnête : la page n'est pas un document juridique validé.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Cette page décrit le fonctionnement réel de l'application. "
                  "Les emplacements marqués « À COMPLÉTER » doivent être "
                  "renseignés par l'éditeur avant publication : ils "
                  "concernent l'identité légale, les contacts et les durées "
                  "de conservation.",
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final PrivacySection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final block in section.blocks) ...[
          _BlockView(block: block),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});

  final PrivacyBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.5);

    switch (block.kind) {
      case PrivacyBlockKind.paragraph:
        return Text(block.text, style: bodyStyle);

      case PrivacyBlockKind.bullets:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              block.text,
              style: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final item in block.items ?? const <String>[])
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 15)),
                    Expanded(child: Text(item, style: bodyStyle)),
                  ],
                ),
              ),
          ],
        );

      case PrivacyBlockKind.note:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Text(block.text, style: bodyStyle),
        );

      case PrivacyBlockKind.placeholder:
        // Volontairement très visible : la page ne doit pas être publiée
        // avec ces emplacements vides.
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: OmniPalette.avertissement.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: OmniPalette.avertissement.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.edit_note, size: 20, color: OmniPalette.avertissement),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.text,
                  style: bodyStyle?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Text(
        'Document technique décrivant les traitements réellement mis en '
            "œuvre. Il ne constitue pas un avis juridique et n'a pas valeur "
            "d'engagement contractuel tant que les emplacements « À COMPLÉTER "
            "» n'ont pas été validés par l'éditeur.",
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
