import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ⚠️ Ce fichier concerne **uniquement les applications Android (APK) et iOS
/// (IPA)**. La PWA (dossier `public/`) conserve son propre design : elle n'est
/// ni modifiée ni impactée.

/// ════════════════════════════════════════════════════════════════════════════
///  OMNI · DESIGN SYSTEM
/// ════════════════════════════════════════════════════════════════════════════
///
/// Identité volontairement distincte de WhatsApp (vert) et Telegram (bleu
/// clair) : **cyan électrique + bleu profond**, contrastes francs, coins
/// asymétriques sur les bulles, typographie serrée. Une seule source de vérité
/// pour les couleurs, les espacements, les rayons et les durées : aucun écran
/// ne doit plus coder une couleur en dur.

// ─── Espacements ───────────────────────────────────────────────────────────
abstract final class OmniEspace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// Marge horizontale standard d'un écran.
  static const double margeEcran = 16;

  static const EdgeInsets paddingEcran = EdgeInsets.symmetric(
    horizontal: margeEcran,
    vertical: l,
  );
}

// ─── Rayons ────────────────────────────────────────────────────────────────
abstract final class OmniRayon {
  static const double xs = 6;
  static const double s = 10;
  static const double m = 14;
  static const double l = 18;
  static const double xl = 24;

  /// Rayon « pastille » (bords entièrement arrondis).
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// Rayon des cartes et panneaux.
  static const BorderRadius carte = BorderRadius.all(Radius.circular(l));

  /// Rayon des champs de saisie.
  static const BorderRadius champ = BorderRadius.all(Radius.circular(m));

  /// Bulle sortante : coin inférieur droit resserré (signature Omni).
  static const BorderRadius bulleSortante = BorderRadius.only(
    topLeft: Radius.circular(l),
    topRight: Radius.circular(l),
    bottomLeft: Radius.circular(l),
    bottomRight: Radius.circular(xs),
  );

  /// Bulle entrante : coin inférieur gauche resserré.
  static const BorderRadius bulleEntrante = BorderRadius.only(
    topLeft: Radius.circular(l),
    topRight: Radius.circular(l),
    bottomLeft: Radius.circular(xs),
    bottomRight: Radius.circular(l),
  );

  /// Bulle isolée dans une série (avant/après un autre interlocuteur).
  static const BorderRadius bulleSeule = BorderRadius.all(Radius.circular(l));
}

// ─── Mouvement ─────────────────────────────────────────────────────────────
abstract final class OmniMouvement {
  static const Duration rapide = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration lent = Duration(milliseconds: 340);

  static const Curve courbe = Curves.easeOutCubic;
  static const Curve courbeEntree = Curves.easeOutQuart;
}

// ─── Typographie ───────────────────────────────────────────────────────────
/// Échelle unique, lisible, légèrement condensée (interlettrage négatif sur
/// les grands corps). Les polices restent celles du système (SF Pro sur iOS,
/// Roboto sur Android) : aucune police distante, aucun téléchargement.
abstract final class OmniTypo {
  static const String _famille = '.SF UI Text';

  static const TextStyle display = TextStyle(
    fontFamily: _famille,
    fontSize: 30,
    height: 1.18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static const TextStyle titre = TextStyle(
    fontFamily: _famille,
    fontSize: 22,
    height: 1.22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const TextStyle sousTitre = TextStyle(
    fontFamily: _famille,
    fontSize: 17,
    height: 1.28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
  );

  static const TextStyle corps = TextStyle(
    fontFamily: _famille,
    fontSize: 15,
    height: 1.42,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
  );

  static const TextStyle corpsGras = TextStyle(
    fontFamily: _famille,
    fontSize: 15,
    height: 1.42,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const TextStyle secondaire = TextStyle(
    fontFamily: _famille,
    fontSize: 13.5,
    height: 1.38,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle etiquette = TextStyle(
    fontFamily: _famille,
    fontSize: 12.5,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle micro = TextStyle(
    fontFamily: _famille,
    fontSize: 11,
    height: 1.28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
}

// ─── Palette brute (valeurs de référence) ──────────────────────────────────
abstract final class OmniPalette {
  // Accents — identité OmniSMS
  static const Color cyan = Color(0xFF00C8FF);
  static const Color bleu = Color(0xFF0057FF);
  static const Color cyanDoux = Color(0xFF5FE0FF);

  // Clair
  static const Color clairFond = Color(0xFFF6F8FC);
  static const Color clairSurface = Color(0xFFFFFFFF);
  static const Color clairSurfaceVariante = Color(0xFFEFF3F9);
  static const Color clairContour = Color(0xFFDFE6F0);
  static const Color clairTexte = Color(0xFF0E1626);
  static const Color clairTexteSecondaire = Color(0xFF5A6B85);
  static const Color clairTexteEstompe = Color(0xFF94A3B8);

  // Sombre
  static const Color sombreFond = Color(0xFF08090F);
  static const Color sombreSurface = Color(0xFF10141D);
  static const Color sombreSurfaceVariante = Color(0xFF171C27);
  static const Color sombreContour = Color(0xFF242B39);
  static const Color sombreTexte = Color(0xFFE9EEF7);
  static const Color sombreTexteSecondaire = Color(0xFF93A1B5);
  static const Color sombreTexteEstompe = Color(0xFF5D6A80);

  // Sémantique
  static const Color succes = Color(0xFF12B76A);
  static const Color erreur = Color(0xFFF04438);
  static const Color avertissement = Color(0xFFF79009);
  static const Color info = Color(0xFF0BA5EC);
}

/// Couleurs **résolues** selon le thème courant (clair ou sombre).
///
/// `final c = OmniCouleurs.of(context);` puis `c.texte`, `c.surface`, etc.
/// Aucune couleur n'est codée en dur dans les écrans : le mode clair comme le
/// mode sombre restent cohérents quoi qu'il arrive.
class OmniCouleurs {
  OmniCouleurs._(
    this.estSombre, {
    required this.fond,
    required this.fondSecondaire,
    required this.surface,
    required this.surfaceVariante,
    required this.contour,
    required this.texte,
    required this.texteSecondaire,
    required this.texteEstompe,
    required this.accent,
    required this.accentSecondaire,
    required this.surAccent,
    required this.bulleSortante,
    required this.bulleSortanteTexte,
    required this.bulleEntrante,
    required this.bulleEntranteTexte,
    required this.ombre,
  });

  final bool estSombre;

  // Fonds
  final Color fond;
  final Color fondSecondaire;
  final Color surface;
  final Color surfaceVariante;
  final Color contour;

  // Texte
  final Color texte;
  final Color texteSecondaire;
  final Color texteEstompe;

  // Accent
  final Color accent;
  final Color accentSecondaire;
  final Color surAccent;

  // Bulles de messages
  final Color bulleSortante;
  final Color bulleSortanteTexte;
  final Color bulleEntrante;
  final Color bulleEntranteTexte;

  /// Couleur d'ombre : très présente en clair, quasi inexistante en sombre
  /// (où l'on utilise des bordures plutôt que des ombres).
  final Color ombre;

  /// Résout la palette depuis le [BuildContext].
  factory OmniCouleurs.of(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return sombre ? OmniCouleurs.sombre() : OmniCouleurs.clair();
  }

  factory OmniCouleurs.clair() {
    return OmniCouleurs._(
      false,
      fond: OmniPalette.clairFond,
      fondSecondaire: OmniPalette.clairSurface,
      surface: OmniPalette.clairSurface,
      surfaceVariante: OmniPalette.clairSurfaceVariante,
      contour: OmniPalette.clairContour,
      texte: OmniPalette.clairTexte,
      texteSecondaire: OmniPalette.clairTexteSecondaire,
      texteEstompe: OmniPalette.clairTexteEstompe,
      accent: const Color(0xFF0093C4), // cyan assombri : contraste AA sur blanc
      accentSecondaire: OmniPalette.bleu,
      surAccent: Colors.white,
      bulleSortante: OmniPalette.cyan,
      bulleSortanteTexte: const Color(0xFF052B38), // texte foncé sur cyan vif
      bulleEntrante: OmniPalette.clairSurface,
      bulleEntranteTexte: OmniPalette.clairTexte,
      ombre: const Color(0x140E1626),
    );
  }

  factory OmniCouleurs.sombre() {
    return OmniCouleurs._(
      true,
      fond: OmniPalette.sombreFond,
      fondSecondaire: OmniPalette.sombreSurface,
      surface: OmniPalette.sombreSurface,
      surfaceVariante: OmniPalette.sombreSurfaceVariante,
      contour: OmniPalette.sombreContour,
      texte: OmniPalette.sombreTexte,
      texteSecondaire: OmniPalette.sombreTexteSecondaire,
      texteEstompe: OmniPalette.sombreTexteEstompe,
      accent: OmniPalette.cyan,
      accentSecondaire: OmniPalette.bleu,
      surAccent: const Color(0xFF04222C),
      bulleSortante: OmniPalette.cyan,
      bulleSortanteTexte: const Color(0xFF04222C),
      bulleEntrante: OmniPalette.sombreSurfaceVariante,
      bulleEntranteTexte: OmniPalette.sombreTexte,
      ombre: const Color(0x40000000),
    );
  }

  /// Dégradé signature (cyan → bleu profond).
  LinearGradient get degradeAccent => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, accentSecondaire],
      );

  /// Accent atténué pour les fonds sélectionnés (12 %).
  Color get accentDoux => accent.withValues(alpha: estSombre ? 0.16 : 0.12);

  /// Accent très atténué pour les séparations et contours actifs (28 %).
  Color get accentContour => accent.withValues(alpha: 0.32);

  /// Barre d'état adaptée (icônes lisibles sur les deux thèmes).
  SystemUiOverlayStyle get overlay => estSombre
      ? const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: OmniPalette.sombreFond,
          systemNavigationBarIconBrightness: Brightness.light,
        )
      : const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: OmniPalette.clairFond,
          systemNavigationBarIconBrightness: Brightness.dark,
        );
}

// ─── Décorations réutilisables ─────────────────────────────────────────────
/// Fabriques de décoration cohérentes : cartes, champs, bulles, panneaux.
abstract final class OmniDecor {
  /// Carte / panneau standard.
  static BoxDecoration carte(OmniCouleurs c, {Color? couleur}) => BoxDecoration(
        color: couleur ?? c.surface,
        borderRadius: OmniRayon.carte,
        border: Border.all(color: c.contour, width: 1),
        boxShadow: c.estSombre
            ? null
            : [
                BoxShadow(
                  color: c.ombre,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      );

  /// Champ de saisie (recherche, message, formulaire).
  static BoxDecoration champ(OmniCouleurs c, {bool actif = false}) =>
      BoxDecoration(
        color: c.surfaceVariante,
        borderRadius: OmniRayon.champ,
        border: Border.all(
          color: actif ? c.accentContour : c.contour,
          width: actif ? 1.4 : 1,
        ),
      );

  /// Bulle de message sortante (dégradé signature).
  static BoxDecoration bulleSortante(OmniCouleurs c) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent, c.accentSecondaire],
        ),
        borderRadius: OmniRayon.bulleSortante,
      );

  /// Bulle de message entrante.
  static BoxDecoration bulleEntrante(OmniCouleurs c) => BoxDecoration(
        color: c.bulleEntrante,
        borderRadius: OmniRayon.bulleEntrante,
        border: Border.all(color: c.contour, width: 1),
      );

  /// Pastille (badge, statut, étiquette).
  static BoxDecoration pastille(OmniCouleurs c, {required Color couleur}) =>
      BoxDecoration(
        color: couleur.withValues(alpha: c.estSombre ? 0.18 : 0.12),
        borderRadius: OmniRayon.pill,
        border: Border.all(
          color: couleur.withValues(alpha: 0.35),
          width: 1,
        ),
      );

  /// Feuille modale (bottom sheet).
  static BoxDecoration feuille(OmniCouleurs c) => BoxDecoration(
        color: c.fondSecondaire,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(OmniRayon.xl),
        ),
      );
}

// ─── États vides / chargement / erreur ─────────────────────────────────────
/// Messages standardisés : jamais de texte technique, jamais d'écran blanc.
abstract final class OmniEtats {
  static const String chargement = 'Chargement…';

  /// Erreur réseau générique, compréhensible par tous.
  static const String reseau =
      'Connexion impossible. Vérifiez votre réseau, puis réessayez.';

  /// Aucun résultat (recherche, filtres).
  static const String aucunResultat = 'Aucun résultat';

  static const String reessayer = 'Réessayer';
}
