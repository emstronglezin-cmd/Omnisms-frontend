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
/// Deux identités visuelles pour la même application.
///
/// Un changement d'identité se juge à l'usage, pas sur une description. Les
/// deux variantes coexistent, sont sélectionnables à tout moment, et
/// l'ancienne n'est jamais supprimée : si la nouvelle ne convient pas, le
/// retour arrière est immédiat et sans perte.
enum OmniVariante {
  /// Identité d'origine : fonds neutres profonds, accent cyan.
  classique,

  /// Variante « Nova » : bleu nuit, dégradés aurore, accents lumineux.
  nova;

  String get libelle => switch (this) {
        OmniVariante.classique => 'Omni Classique',
        OmniVariante.nova => 'Omni Nova',
      };

  String get description => switch (this) {
        OmniVariante.classique =>
          'Fonds neutres profonds, accent cyan, contrastes francs.',
        OmniVariante.nova =>
          'Bleu nuit, dégradés aurore, surfaces translucides et accents lumineux.',
      };
}

/// Les jetons de la variante courante, transportés par le thème.
///
/// Le mécanisme est un `ThemeExtension` : la palette voyage avec le
/// `ThemeData`. Quand la variante change, Flutter reconstruit l'interface et
/// chaque `OmniCouleurs.of(context)` renvoie la nouvelle palette — sans
/// qu'aucun écran n'ait à être modifié, ni même à être au courant.
class OmniJetons extends ThemeExtension<OmniJetons> {
  const OmniJetons({required this.couleurs, required this.variante});

  final OmniCouleurs couleurs;
  final OmniVariante variante;

  bool get estNova => variante == OmniVariante.nova;

  /// Dégradé aurore, signature de Nova. Sur la variante classique il reprend
  /// le dégradé d'accent : le code appelant n'a pas à distinguer les deux.
  LinearGradient get degradeAurore => estNova
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OmniNovaPalette.cyan,
            OmniNovaPalette.indigo,
            OmniNovaPalette.magenta,
          ],
        )
      : couleurs.degradeAccent;

  @override
  ThemeExtension<OmniJetons> copyWith({
    OmniCouleurs? couleurs,
    OmniVariante? variante,
  }) =>
      OmniJetons(
        couleurs: couleurs ?? this.couleurs,
        variante: variante ?? this.variante,
      );

  @override
  ThemeExtension<OmniJetons> lerp(
    covariant ThemeExtension<OmniJetons>? autre,
    double t,
  ) {
    // La palette ne s'interpole pas : un mélange des deux identités
    // produirait des teintes intermédiaires qui n'appartiennent à aucune.
    // Le basculement est donc franc.
    if (autre is! OmniJetons) return this;
    return t < 0.5 ? this : autre;
  }
}

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

  // ──────────────────────────────────────────────────────────────────────────
  // V3 — durées et courbes alignées sur Material 3 / Material 3 Expressive.
  //
  // Chaque valeur correspond à un usage précis et documenté : aucune durée
  // n'est libre. Le principe directeur est qu'un retour au toucher doit être
  // perçu comme instantané (≤ 100 ms) alors qu'un changement d'écran peut
  // durer (400–500 ms) parce que l'utilisateur observe un déplacement.
  // ──────────────────────────────────────────────────────────────────────────

  /// Retour tactile immédiat. Au-delà de ~100 ms l'interface paraît molle.
  static const Duration instantane = Duration(milliseconds: 80);

  /// Micro-interaction : badge, changement d'état d'une icône.
  static const Duration court = Duration(milliseconds: 150);

  /// Transition utilitaire : menu, bascule d'onglet.
  static const Duration moyen = Duration(milliseconds: 300);

  /// Transition d'écran complète (l'élément entre et reste).
  static const Duration long = Duration(milliseconds: 500);

  /// Entrée d'un élément à l'écran (courbe décélérée).
  static const Duration entree = Duration(milliseconds: 400);

  /// Sortie définitive de l'écran.
  static const Duration sortie = Duration(milliseconds: 200);

  /// Moment expressif : validation, démarrage. Un seul par parcours.
  static const Duration expressif = Duration(milliseconds: 700);

  /// Balayage d'un squelette de chargement.
  static const Duration squelette = Duration(milliseconds: 1200);

  /// Courbe « emphasized » — cubic-bezier(0.2, 0, 0, 1).
  static const Curve appuye = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Entrée — cubic-bezier(0.05, 0.7, 0.1, 1) : part vite, se pose en freinant.
  static const Curve arrivee = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Sortie définitive — cubic-bezier(0.3, 0, 0.8, 0.15).
  static const Curve depart = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Sortie temporaire — cubic-bezier(0.4, 0, 0.2, 1).
  static const Curve standard = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Décélération douce pour les apparitions discrètes.
  static const Curve doux = Curves.easeOutCubic;

  /// Accélération pour les disparitions discrètes.
  static const Curve vif = Curves.easeInCubic;

  /// Ressort raide, sans dépassement (micro-interactions).
  static const SpringDescription ressortCourt = SpringDescription(
    mass: 1,
    stiffness: 900,
    damping: 34,
  );

  /// Ressort légèrement rebondi (feuilles, panneaux).
  static const SpringDescription ressortMoyen = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 30,
  );

  /// Ressort ample (feuille plein écran).
  static const SpringDescription ressortLong = SpringDescription(
    mass: 1,
    stiffness: 220,
    damping: 26,
  );

  /// Vrai si l'utilisateur a demandé la réduction des animations
  /// (réglage système, iOS comme Android).
  static bool animationsReduites(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Durée à utiliser : nulle quand les animations sont réduites.
  static Duration duree(BuildContext context, Duration souhaitee) =>
      animationsReduites(context) ? Duration.zero : souhaitee;
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
/// Palette de la variante « Nova » (bleu nuit, accents aurore).
///
/// Elle reprend **exactement la même structure** que [OmniPalette] : mêmes
/// rôles, mêmes niveaux. C'est ce qui permet à chaque écran de s'afficher
/// dans l'une ou l'autre identité sans qu'une seule ligne d'écran ne change.
abstract final class OmniNovaPalette {
  // Fonds — bleu nuit profond, légèrement violacé.
  static const Color sombreFond = Color(0xFF050A18);
  static const Color sombreFondSecondaire = Color(0xFF0A1229);
  static const Color sombreSurface = Color(0xFF0E1833);
  static const Color sombreSurfaceVariante = Color(0xFF152043);
  static const Color sombreContour = Color(0xFF24325C);

  // Texte — légèrement bleuté pour s'accorder au fond.
  static const Color sombreTexte = Color(0xFFEAF0FF);
  static const Color sombreTexteSecondaire = Color(0xFF9AAAD4);
  static const Color sombreTexteEstompe = Color(0xFF64739E);

  // Clair — mêmes teintes, valeurs très pâles.
  static const Color clairFond = Color(0xFFF4F7FF);
  static const Color clairSurface = Color(0xFFFFFFFF);
  static const Color clairSurfaceVariante = Color(0xFFE9EEFB);
  static const Color clairContour = Color(0xFFD3DCF2);
  static const Color clairTexte = Color(0xFF0A1330);
  static const Color clairTexteSecondaire = Color(0xFF54628C);
  static const Color clairTexteEstompe = Color(0xFF8D99BE);

  // Accents aurore : cyan → indigo → magenta.
  static const Color cyan = Color(0xFF35E6FF);
  static const Color indigo = Color(0xFF6C5CE7);
  static const Color magenta = Color(0xFFFF5FD2);
}

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
    this.estNova = false,
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

  /// Vrai si cette palette appartient à la variante Nova.
  final bool estNova;

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
    // Si le thème porte des jetons (cas normal), ils font foi : c'est ce qui
    // permet à la même arborescence d'écrans de s'afficher dans l'une ou
    // l'autre identité. À défaut, on retombe sur la luminosité, pour qu'aucun
    // écran ne puisse se retrouver sans couleurs.
    final jetons = Theme.of(context).extension<OmniJetons>();
    if (jetons != null) return jetons.couleurs;
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

  /// Variante Nova, thème clair. Même structure de jetons, autres couleurs.
  factory OmniCouleurs.novaClair() => OmniCouleurs._(
        false,
        estNova: true,
        fond: OmniNovaPalette.clairFond,
        fondSecondaire: OmniNovaPalette.clairSurface,
        surface: OmniNovaPalette.clairSurface,
        surfaceVariante: OmniNovaPalette.clairSurfaceVariante,
        contour: OmniNovaPalette.clairContour,
        texte: OmniNovaPalette.clairTexte,
        texteSecondaire: OmniNovaPalette.clairTexteSecondaire,
        texteEstompe: OmniNovaPalette.clairTexteEstompe,
        // Indigo assombri : contraste AA sur fond blanc.
        accent: const Color(0xFF5B3FD6),
        accentSecondaire: OmniNovaPalette.indigo,
        surAccent: Colors.white,
        bulleSortante: const Color(0xFF6C5CE7),
        bulleSortanteTexte: Colors.white,
        bulleEntrante: OmniNovaPalette.clairSurfaceVariante,
        bulleEntranteTexte: OmniNovaPalette.clairTexte,
        ombre: const Color(0x1F0A1330),
      );

  /// Variante Nova, thème sombre.
  factory OmniCouleurs.novaSombre() => OmniCouleurs._(
        true,
        estNova: true,
        fond: OmniNovaPalette.sombreFond,
        fondSecondaire: OmniNovaPalette.sombreFondSecondaire,
        surface: OmniNovaPalette.sombreSurface,
        surfaceVariante: OmniNovaPalette.sombreSurfaceVariante,
        contour: OmniNovaPalette.sombreContour,
        texte: OmniNovaPalette.sombreTexte,
        texteSecondaire: OmniNovaPalette.sombreTexteSecondaire,
        texteEstompe: OmniNovaPalette.sombreTexteEstompe,
        accent: OmniNovaPalette.cyan,
        accentSecondaire: OmniNovaPalette.indigo,
        // Texte foncé sur accent clair : jamais de blanc sur cyan pâle.
        surAccent: const Color(0xFF050A18),
        bulleSortante: OmniNovaPalette.indigo,
        bulleSortanteTexte: Colors.white,
        bulleEntrante: OmniNovaPalette.sombreSurfaceVariante,
        bulleEntranteTexte: OmniNovaPalette.sombreTexte,
        ombre: const Color(0x66000000),
      );

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

  // ─── Profondeur ───────────────────────────────────────────────────────────
  // Une interface sombre ne se lit pas par ses ombres : elle se lit par ses
  // plans. Plus une surface est proche de l'utilisateur, plus elle est claire.
  // Cinq niveaux sont définis, là où un fond unique aplati tout.

  /// Fond le plus éloigné, celui de l'écran.
  Color get planFond => fond;

  /// Plan intermédiaire : sections, en-têtes collants.
  Color get planIntermediaire =>
      estSombre ? Color.lerp(fond, fondSecondaire, 0.5)! : fondSecondaire;

  /// Plan des cartes posées sur le fond.
  Color get planCarte => surface;

  /// Plan des éléments interactifs dans une carte (chips, boutons secondaires).
  Color get planEleve => surfaceVariante;

  /// Plan le plus proche : couches flottantes, menus, feuilles modales.
  Color get planFlottant => estSombre
      ? Color.lerp(surfaceVariante, Colors.white, estNova ? 0.10 : 0.06)!
      : Colors.white;

  // ─── Verre (Liquid Glass) ─────────────────────────────────────────────────
  // Le verre est réservé aux couches qui recouvrent du contenu : barre de
  // navigation, en-tête qui défile, champ de saisie, feuilles modales, cartes
  // d'action. Le flou y signifie « ceci est temporaire, ce dessous existe
  // encore ». Sur un fond plein il ne renseigne sur rien et coûte cher.

  /// Remplissage d'une couche de verre posée sur du contenu.
  Color get verre => estSombre
      ? (estNova ? planFlottant.withValues(alpha: 0.58)
                 : planFlottant.withValues(alpha: 0.74))
      : Colors.white.withValues(alpha: estNova ? 0.58 : 0.74);

  /// Verre d'une couche flottante, plus opaque car du contenu défile dessous.
  Color get verreFlottant => estSombre
      ? (estNova ? planFlottant.withValues(alpha: 0.78)
                 : planFlottant.withValues(alpha: 0.88))
      : Colors.white.withValues(alpha: estNova ? 0.80 : 0.90);

  /// Liseré du verre. Un trait clair à 1 px matérialise la tranche : c'est lui,
  /// et non une ombre, qui donne le relief en thème sombre.
  Color get verreContour => Colors.white.withValues(alpha: estSombre
      ? (estNova ? 0.16 : 0.10)
      : (estNova ? 0.62 : 0.50));

  /// Reflet interne : léger éclaircissement du coin supérieur gauche.
  LinearGradient get verreReflet => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: estNova ? 0.07 : 0.045),
          Colors.transparent,
        ],
        stops: const [0.0, 0.62],
      );

  /// Halo d'accent. En sombre il remplace l'ombre portée : la lumière émane de
  /// l'élément au lieu d'être projetée par lui.
  Color get lueur => accent.withValues(
        alpha: estSombre ? (estNova ? 0.32 : 0.18) : 0.14,
      );

  /// Dégradé aurore de la variante courante (cyan → indigo → magenta sur Nova,
  /// cyan → bleu sur Classique). Les écrans n'ont pas à distinguer les deux.
  LinearGradient get degradeAurore => estNova
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OmniNovaPalette.cyan,
            OmniNovaPalette.indigo,
            OmniNovaPalette.magenta,
          ],
          stops: [0.0, 0.55, 1.0],
        )
      : degradeAccent;

  /// Flou du verre, en pixels logiques. Nova est plus translucide donc plus
  /// floutée : sans cela le contenu derrière se lit et parasite le premier plan.
  double get verreFlou => estNova ? 22.0 : 16.0;

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
  ///
  /// En Nova la carte porte un reflet interne : en thème sombre un fond plat
  /// paraît éteint, un très léger éclaircissement du bord haut suffit à lui
  /// donner une épaisseur. Classique garde sa carte neutre d'origine.
  static BoxDecoration carte(OmniCouleurs c, {Color? couleur}) => BoxDecoration(
        color: couleur ?? c.surface,
        borderRadius: OmniRayon.carte,
        border: Border.all(color: c.contour, width: 1),
        gradient: c.estNova ? c.verreReflet : null,
        boxShadow: c.estSombre
            ? (c.estNova
                ? [
                    BoxShadow(
                      color: c.lueur.withValues(alpha: 0.35),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null)
            : [
                BoxShadow(
                  color: c.ombre,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      );

  /// Champ de saisie (recherche, message, formulaire).
  ///
  /// En Nova le champ est en verre : il repose sur le fond aurore et le
  /// laisse transparaître, ce qui le rattache visuellement à l'écran.
  static BoxDecoration champ(OmniCouleurs c, {bool actif = false}) =>
      BoxDecoration(
        color: c.estNova ? c.verre : c.surfaceVariante,
        borderRadius: OmniRayon.champ,
        border: Border.all(
          color: actif ? c.accentContour : (c.estNova ? c.verreContour : c.contour),
          width: actif ? 1.4 : 1,
        ),
      );

  /// Bulle de message sortante (dégradé signature).
  ///
  /// Nova peint la bulle dans le dégradé aurore et lui donne un halo : c'est
  /// l'élément le plus regardé de l'application, c'est donc lui qui porte
  /// l'identité. Classique conserve son dégradé cyan → bleu.
  static BoxDecoration bulleSortante(OmniCouleurs c) => BoxDecoration(
        gradient: c.degradeAurore,
        borderRadius: OmniRayon.bulleSortante,
        boxShadow: c.estNova
            ? [
                BoxShadow(
                  color: c.lueur,
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      );

  /// Bulle de message entrante.
  ///
  /// Nova la rend translucide avec un liseré : posée sur le fond aurore, elle
  /// laisse passer la lumière sans la laisser lire, et le liseré marque sa
  /// tranche. Classique conserve sa bulle opaque.
  static BoxDecoration bulleEntrante(OmniCouleurs c) => BoxDecoration(
        color: c.estNova ? c.verre : c.bulleEntrante,
        borderRadius: OmniRayon.bulleEntrante,
        border: Border.all(
          color: c.estNova ? c.verreContour : c.contour,
          width: 1,
        ),
        gradient: c.estNova ? c.verreReflet : null,
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
  ///
  /// Une feuille recouvre du contenu : c'est le cas d'usage légitime du verre.
  /// Nova la rend translucide, Classique la garde pleine.
  static BoxDecoration feuille(OmniCouleurs c) => BoxDecoration(
        color: c.estNova ? c.verreFlottant : c.fondSecondaire,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(OmniRayon.xl),
        ),
        border: c.estNova ? Border(top: BorderSide(color: c.verreContour)) : null,
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
