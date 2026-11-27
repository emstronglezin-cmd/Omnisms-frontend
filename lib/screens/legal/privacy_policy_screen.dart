import 'package:flutter/material.dart';

import 'legal_document_view.dart';
import 'privacy_content.dart';

/// Page « Politique de confidentialité » — publique, sans connexion requise.
///
/// Accessible :
///   - depuis l'application : Connexion, Inscription, Paramètres ;
///   - depuis le web : route publique `/privacy` (même adresse que la PWA) ;
///   - via la route nommée `/privacy` de `MaterialApp` (main.dart).
///
/// La mise en page est partagée avec les conditions générales d'utilisation
/// ([LegalDocumentView]) : mêmes largeurs (820 dp), mêmes marges adaptatives
/// (téléphone / tablette / ordinateur), texte sélectionnable et même rendu des
/// emplacements « À COMPLÉTER ».
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

    return LegalDocumentView(
      showAppBar: showAppBar,
      document: LegalDocument(
        title: 'Politique de confidentialité',
        updatedOn: content.updatedOn,
        introNote:
            "Cette page décrit le fonctionnement réel de l'application. "
            "Les emplacements marqués « À COMPLÉTER » doivent être "
            "renseignés par l'éditeur avant publication : ils "
            "concernent l'identité légale, les contacts et les durées "
            "de conservation.",
        sections: content.sections,
        footer:
            'Document technique décrivant les traitements réellement mis en '
            "œuvre. Il ne constitue pas un avis juridique et n'a pas valeur "
            "d'engagement contractuel tant que les emplacements « À COMPLÉTER "
            "» n'ont pas été validés par l'éditeur.",
      ),
    );
  }
}
