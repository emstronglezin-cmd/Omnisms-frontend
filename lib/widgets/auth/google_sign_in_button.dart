import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bouton « Continuer avec Google ».
///
/// Utilise le **logo officiel Google** (4 couleurs de la marque), fourni par
/// l'asset `assets/images/google_g_logo.svg` — jamais une lettre « G »
/// stylisée, un emoji ou un dessin approximatif.
///
/// Conformité règles de marque Google :
///   • logo affiché en 20 dp (recommandation : 18 à 24 dp) ;
///   • zone de respect de 12 dp entre le logo et le libellé ;
///   • libellé exact « Continuer avec Google », inchangé ;
///   • le fichier SVG n'est pas modifié (géométrie et couleurs d'origine).
///
/// Le bouton reste désactivable pendant un flux ([isLoading], [enabled]) pour
/// éviter les doubles clics — donc les doubles ouvertures de navigateur.
class GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;

  /// Chemin de l'asset du logo officiel.
  static const String logoAsset = 'assets/images/google_g_logo.svg';

  /// Bleu Google (#4285F4) — utilisé uniquement pour l'indicateur de
  /// chargement, le logo restant l'asset officiel.
  static const Color googleBlue = Color(0xFF4285F4);

  const GoogleSignInButton({
    super.key,
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: 'Continuer avec Google',
      enabled: enabled && !isLoading,
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          // Désactivé pendant tout flux d'authentification (anti double-clic).
          onPressed: (enabled && !isLoading) ? onPressed : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF1B1F27) : Colors.white,
            foregroundColor: isDark ? Colors.white : const Color(0xFF3C4043),
            side: BorderSide(
              color: isDark ? Colors.white24 : const Color(0xFFDADCE0),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: googleBlue,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo officiel Google « G » (4 couleurs).
                    SvgPicture.asset(
                      logoAsset,
                      width: 20,
                      height: 20,
                      semanticsLabel: 'Logo Google',
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continuer avec Google',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
