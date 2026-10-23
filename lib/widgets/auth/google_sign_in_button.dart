import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bouton « Continuer avec Google » — présentation uniquement.
///
/// Ce widget ne contient AUCUNE logique d'authentification : il se contente
/// d'appeler [onPressed]. Le flux OAuth complet (ouverture du navigateur,
/// consentement Google, retour par deep link `omnisms://auth` / App Link,
/// échange du code côté backend et ouverture de session) reste entièrement
/// géré par `AuthProvider` / `google_oauth_flow.dart`, qui ne sont pas
/// modifiés ici.
///
/// Choix de rendu :
///   - logo officiel Google « G » 4 couleurs (`assets/images/google_g_logo.svg`),
///     déclaré dans `pubspec.yaml` ;
///   - mêmes proportions que le bouton principal de l'app (hauteur 52, rayon 12) ;
///   - état de chargement explicite (indicateur à la place du logo, bouton
///     désactivé) sans décalage de mise en page ;
///   - accessible (sémantique « bouton » + libellé complet) et responsive
///     (largeur maximale de 400 dp pour rester lisible sur desktop).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.label = 'Continuer avec Google',
    this.maxWidth = 400,
  });

  /// Callback d'authentification. **Ne doit rien contenir d'autre que le flux
  /// Google existant** (`AuthProvider.loginWithGoogle`).
  final VoidCallback onPressed;

  /// `true` pendant l'échange du code : le bouton se désactive pour éviter
  /// les doubles lancements du flux OAuth.
  final bool isLoading;

  /// `false` pour désactiver le bouton (ex. une autre opération est en cours).
  final bool enabled;

  /// Libellé affiché (surchargeable pour une future traduction).
  final String label;

  /// Largeur maximale du bouton (desktop).
  final double maxWidth;

  static const double _height = 52;
  static const double _logoSize = 20;
  static const double _gap = 12;
  static const double _radius = 12;
  static const Color _borderLight = Color(0xFFDADCE0);
  static const Color _borderDark = Color(0xFF5F6368);
  static const Color _backgroundLight = Colors.white;
  static const Color _backgroundDark = Color(0xFF202124);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Désactivé pendant le chargement OU si l'appelant le demande : un
    // second clic relancerait tout le flux OAuth et casserait l'échange du
    // code côté serveur.
    final enabled = this.enabled && !isLoading;
    final textColor = isDark ? Colors.white : const Color(0xFF1F1F1F);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(
            width: double.infinity,
            height: _height,
            child: OutlinedButton(
              // Désactivé pendant le chargement : un second appel relancerait
              // tout le flux OAuth et casserait l'échange du code.
              onPressed: enabled ? onPressed : null,
              style: OutlinedButton.styleFrom(
                backgroundColor:
                    isDark ? _backgroundDark : _backgroundLight,
                foregroundColor: textColor,
                disabledForegroundColor: textColor.withValues(alpha: 0.38),
                disabledBackgroundColor:
                    (isDark ? _backgroundDark : _backgroundLight)
                        .withValues(alpha: 0.6),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
                side: BorderSide(
                  color: isDark ? _borderDark : _borderLight,
                  width: 1,
                ),
                // Le contenu est centré par nos soins (Row + MainAxisSize.min).
                alignment: Alignment.center,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _logoSize,
                    height: _logoSize,
                    child: isLoading
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(textColor),
                          )
                        : SvgPicture.asset(
                            'assets/images/google_g_logo.svg',
                            width: _logoSize,
                            height: _logoSize,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                            // Pas de « boîte d'erreur » rouge dans l'UI si
                            // l'asset ne se charge pas : le bouton reste
                            // parfaitement identifiable par son libellé et
                            // l'échec est journalisé (voir plus bas).
                            placeholderBuilder: (_) => const SizedBox.shrink(),
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                  ),
                  const SizedBox(width: _gap),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: (theme.textTheme.titleMedium ?? const TextStyle())
                          .copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: enabled
                            ? textColor
                            : textColor.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Journalise un éventuel échec de chargement du logo (jamais affiché tel
/// quel à l'utilisateur). Conservé pour le diagnostic, conformément à la
/// règle « ne pas masquer les erreurs réelles » : elles restent dans les
/// journaux, pas dans l'interface.
void debugLogGoogleLogoFailure(Object error) {
  debugPrint('[GoogleSignInButton] logo non chargé: $error');
}
