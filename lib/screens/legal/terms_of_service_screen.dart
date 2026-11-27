import 'package:flutter/material.dart';

import 'legal_document_view.dart';
import 'terms_content.dart';

/// Page « Conditions générales d'utilisation » — publique, sans connexion.
///
/// Accessible :
///   - depuis l'application : Connexion, Inscription, Paramètres ;
///   - depuis le web : route publique `/terms` (même adresse que la PWA) ;
///   - via la route nommée `/terms` de `MaterialApp` (main.dart).
///
/// La mise en page est partagée avec la politique de confidentialité
/// ([LegalDocumentView]) : mêmes largeurs, mêmes encadrés et même rendu des
/// emplacements « À COMPLÉTER », qui restent visibles tant que l'éditeur n'a
/// pas renseigné les mentions juridiques.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key, this.showAppBar = true});

  /// Mettre `false` pour une intégration dans un autre écran (ex. onglet).
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final content = termsContentFor(Localizations.localeOf(context));

    return LegalDocumentView(
      showAppBar: showAppBar,
      document: LegalDocument(
        title: "Conditions générales d'utilisation",
        updatedOn: content.updatedOn,
        introNote:
            "Cette page décrit le fonctionnement réel du service. Les "
            "emplacements marqués « À COMPLÉTER » doivent être renseignés par "
            "l'éditeur avant publication : ils concernent l'identité légale, "
            "les engagements contractuels, les tarifs et le droit applicable.",
        sections: content.sections,
        footer:
            "Document décrivant le service tel qu'il est réellement mis en "
            "œuvre dans l'application. Il ne constitue pas un avis juridique "
            "et n'a pas valeur d'engagement contractuel tant que les "
            "emplacements « À COMPLÉTER » n'ont pas été validés par "
            "l'éditeur.",
      ),
    );
  }
}
