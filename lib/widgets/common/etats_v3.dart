import 'package:flutter/material.dart';

import '../../theme/omni_design.dart';
import '../../theme/omni_motion.dart';
import '../../theme/omni_responsive.dart';

/// États remarquables de l'interface OmniSMS V3 : vide, erreur, succès.
///
/// Pourquoi un fichier dédié : un écran qui n'a rien à afficher est un
/// moment décisif. C'est là que l'utilisateur décide si l'application est
/// finie ou abandonnée. Trois règles sont appliquées ici, et elles valent
/// pour tous les écrans :
///
/// 1. **Jamais d'écran blanc.** Un état vide explique ce qui manque et
///    propose la suite.
/// 2. **La forme du contenu est montrée pendant le chargement**, pas un
///    cercle tournant seul.
/// 3. **Le succès est confirmé visuellement.** Une action qui ne produit
///    aucun retour laisse l'utilisateur douter — il recommence, et crée un
///    doublon.

/// État vide : icône en médaillon, explication, action.
class OmniEtatVide extends StatelessWidget {
  const OmniEtatVide({
    super.key,
    required this.icone,
    required this.titre,
    this.message,
    this.libelleAction,
    this.onAction,
    this.compact = false,
  });

  final IconData icone;
  final String titre;
  final String? message;
  final String? libelleAction;
  final VoidCallback? onAction;

  /// Réduit les espacements : utilisé quand l'état vide occupe une zone
  /// restreinte (volet d'un panneau, partie basse d'un écran).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final marge = compact ? OmniEspace.l : OmniEspace.xxxl;

    return OmniContenuCentre(
      child: Padding(
        padding: EdgeInsets.all(marge),
        child: SingleChildScrollView(
          // Sans défilement, l'état vide devient un écran mort sur les
          // petits téléphones quand le clavier est ouvert.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              OmniApparition(
                child: Container(
                  width: compact ? 72 : 96,
                  height: compact ? 72 : 96,
                  decoration: BoxDecoration(
                    color: c.accentDoux,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icone,
                    size: compact ? 34 : 44,
                    color: c.accent,
                  ),
                ),
              ),
              SizedBox(height: compact ? OmniEspace.m : OmniEspace.xl),
              OmniApparitionEspacee(
                index: 1,
                pas: const Duration(milliseconds: 60),
                child: Text(
                  titre,
                  textAlign: TextAlign.center,
                  style: OmniTypo.sousTitre.copyWith(color: c.texte),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: OmniEspace.xs),
                OmniApparitionEspacee(
                  index: 2,
                  pas: const Duration(milliseconds: 60),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: OmniTypo.secondaire
                        .copyWith(color: c.texteSecondaire),
                  ),
                ),
              ],
              if (libelleAction != null && onAction != null) ...[
                SizedBox(height: compact ? OmniEspace.m : OmniEspace.xl),
                OmniApparitionEspacee(
                  index: 3,
                  pas: const Duration(milliseconds: 60),
                  child: OmniPression(
                    borderRadius: OmniRayon.pill,
                    onTap: onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: OmniEspace.xl,
                        vertical: OmniEspace.m,
                      ),
                      decoration: BoxDecoration(
                        gradient: c.degradeAccent,
                        borderRadius: OmniRayon.pill,
                      ),
                      child: Text(
                        libelleAction!,
                        style: OmniTypo.corpsGras.copyWith(color: c.surAccent),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// État d'erreur : message lisible et action de reprise.
///
/// Le message affiché vient du fournisseur, qui le traduit déjà en langage
/// courant (`utils/user_messages.dart`) : jamais d'exception brute.
class OmniEtatErreur extends StatelessWidget {
  const OmniEtatErreur({
    super.key,
    required this.message,
    this.onReessayer,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onReessayer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);

    return OmniContenuCentre(
      child: Padding(
        padding: EdgeInsets.all(compact ? OmniEspace.l : OmniEspace.xxxl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              OmniApparition(
                child: Container(
                  width: compact ? 72 : 96,
                  height: compact ? 72 : 96,
                  decoration: BoxDecoration(
                    color: OmniPalette.erreur.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: compact ? 34 : 44,
                    color: OmniPalette.erreur,
                  ),
                ),
              ),
              SizedBox(height: compact ? OmniEspace.m : OmniEspace.xl),
              OmniApparitionEspacee(
                index: 1,
                pas: const Duration(milliseconds: 60),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: OmniTypo.secondaire.copyWith(color: c.texteSecondaire),
                ),
              ),
              if (onReessayer != null) ...[
                const SizedBox(height: OmniEspace.xl),
                OmniApparitionEspacee(
                  index: 2,
                  pas: const Duration(milliseconds: 60),
                  child: OmniPression(
                    borderRadius: OmniRayon.pill,
                    onTap: onReessayer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: OmniEspace.xl,
                        vertical: OmniEspace.m,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceVariante,
                        borderRadius: OmniRayon.pill,
                        border: Border.all(color: c.contour),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, size: 18, color: c.texte),
                          const SizedBox(width: OmniEspace.s),
                          Text(
                            OmniEtats.reessayer,
                            style: OmniTypo.corpsGras.copyWith(color: c.texte),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Étape de chargement : la forme du contenu attendu, pas un cercle seul.
class OmniEtatChargement extends StatelessWidget {
  const OmniEtatChargement({super.key, this.nombreLignes = 5});

  final int nombreLignes;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: OmniEspace.m),
      itemCount: nombreLignes,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OmniEspace.l,
          vertical: OmniEspace.s,
        ),
        child: Row(
          children: [
            const OmniSquelette(largeur: 48, hauteur: 48, rayon: 24),
            const SizedBox(width: OmniEspace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OmniSquelette(
                    largeur: double.infinity,
                    hauteur: 13,
                    rayon: OmniRayon.xs,
                  ),
                  const SizedBox(height: OmniEspace.s),
                  OmniSquelette(
                    largeur: double.infinity,
                    hauteur: 11,
                    rayon: OmniRayon.xs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Affiche une confirmation de succès.
///
/// Pourquoi un retour visuel systématique : sans confirmation, l'utilisateur
/// qui ne voit pas le résultat immédiat de son action la rejoue — et crée
/// un doublon. Le coût d'un bandeau est minime, celui d'un doublon ne l'est
/// pas.
void afficherSucces(BuildContext context, String message) {
  final c = OmniCouleurs.of(context);

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surface,
        elevation: 0,
        margin: const EdgeInsets.all(OmniEspace.m),
        shape: RoundedRectangleBorder(
          borderRadius: OmniRayon.champ,
          side: BorderSide(color: c.contour),
        ),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: OmniPalette.succes,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: OmniEspace.m),
            Expanded(
              child: Text(
                message,
                style: OmniTypo.secondaire.copyWith(color: c.texte),
              ),
            ),
          ],
        ),
      ),
    );
}
