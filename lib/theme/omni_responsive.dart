import 'package:flutter/material.dart';
import 'omni_design.dart';

/// Classes de taille de fenêtre (Material 3).
///
/// Material 3 ne raisonne plus en « téléphone / tablette » mais en classe de
/// taille de fenêtre, ce qui est exactement ce dont une application qui doit
/// tourner sur un petit téléphone comme sur un appareil pliable a besoin.
enum OmniTailleFenetre {
  /// Largeur < 600 dp : téléphone en portrait, usage à une main.
  compacte,

  /// 600 – 839 dp : téléphone en paysage, petit pliable, tablette portrait.
  moyenne,

  /// ≥ 840 dp : tablette, pliable ouvert, grand écran.
  etendue,
}

/// Résumé de l'espace disponible, calculé une fois par reconstruction.
///
/// Les écrans V3 lisent cet objet au lieu d'interroger [MediaQuery] à
/// plusieurs endroits : une seule source de vérité, donc pas de valeurs
/// contradictoires d'un widget à l'autre.
class OmniMetriques {
  const OmniMetriques({
    required this.largeur,
    required this.hauteur,
    required this.taille,
    required this.marge,
    required this.largeurContenuMax,
    required this.colonnes,
    required this.echelleTexte,
    required this.paddingBas,
    required this.paddingHaut,
    required this.clavierOuvert,
  });

  /// Largeur utile en dp.
  final double largeur;

  /// Hauteur utile en dp.
  final double hauteur;

  /// Classe de taille de fenêtre.
  final OmniTailleFenetre taille;

  /// Marge latérale à appliquer au contenu d'un écran.
  final double marge;

  /// Largeur maximale d'un bloc de contenu centré (lisibilité sur grand
  /// écran : une ligne de texte ne devrait pas dépasser ~700 dp).
  final double largeurContenuMax;

  /// Nombre de colonnes pour une grille (cartes, statistiques, contacts).
  final int colonnes;

  /// Facteur d'échelle du texte demandé par l'utilisateur.
  final double echelleTexte;

  /// Zone système en bas (barre de navigation gestuelle, indicateur Home).
  final double paddingBas;

  /// Zone système en haut (encoche, barre d'état).
  final double paddingHaut;

  /// Vrai quand le clavier virtuel est déployé.
  final bool clavierOuvert;

  // -------------------------------------------------------------------------
  // Raccourcis de lisibilité
  // -------------------------------------------------------------------------

  bool get estCompacte => taille == OmniTailleFenetre.compacte;
  bool get estMoyenne => taille == OmniTailleFenetre.moyenne;
  bool get estEtendue => taille == OmniTailleFenetre.etendue;

  /// Vrai sur un grand écran : le contenu peut être disposé en deux volets
  /// (liste + détail) au lieu d'empiler les écrans.
  bool get accepteDeuxVolets => taille != OmniTailleFenetre.compacte;

  /// Vrai quand la hauteur devient critique (petit écran + clavier ouvert).
  /// Les écrans doivent alors masquer les éléments non essentiels.
  bool get hauteurCritique => hauteur < 480;

  /// Rayon de la barre de navigation flottante : nulle sur petit écran
  /// (barre pleine largeur), arrondie et détachée sur grand écran.
  double get rayonBarreNavigation => estCompacte ? 0 : OmniRayon.xl;

  @override
  String toString() =>
      'OmniMetriques(${largeur.round()}x${hauteur.round()} $taille, '
      'col=$colonnes, clavier=$clavierOuvert)';
}

/// Fournit l'espace disponible à toute l'application V3.
///
/// S'utilise comme [MediaQuery] : `final espace = OmniResponsive.of(context);`
class OmniResponsive extends StatelessWidget {
  const OmniResponsive({super.key, required this.child});

  final Widget child;

  /// Lit l'espace courant. Lève une erreur explicite si le widget n'est pas
  /// placé — mieux vaut une erreur claire qu'une valeur par défaut qui
  /// masque un problème de mise en page.
  static OmniMetriques of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_OmniResponsiveHerite>();
    if (scope == null) {
      throw FlutterError(
        'OmniResponsive.of() appelé sans OmniResponsive au-dessus dans '
        "l'arbre. Enveloppez l'écran avec un widget OmniResponsive.",
      );
    }
    return scope.espace;
  }

  /// Variante tolérante : renvoie `null` au lieu de lever.
  static OmniMetriques? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_OmniResponsiveHerite>()
        ?.espace;
  }

  /// Calcule l'espace à partir d'un [MediaQueryData], sans contexte.
  /// Utilisé par les tests et les captures.
  static OmniMetriques depuis(MediaQueryData donnees) {
    final largeur = donnees.size.width;
    final hauteur = donnees.size.height;

    final taille = largeur < 600
        ? OmniTailleFenetre.compacte
        : largeur < 840
            ? OmniTailleFenetre.moyenne
            : OmniTailleFenetre.etendue;

    // Marges : 16 dp sur téléphone, 24 en moyenne, 32 sur grand écran.
    // Une marge plus généreuse sur grand écran évite l'effet « bande
    // étirée » et laisse respirer le contenu.
    final marge = switch (taille) {
      OmniTailleFenetre.compacte => OmniEspace.l,
      OmniTailleFenetre.moyenne => OmniEspace.xxl,
      OmniTailleFenetre.etendue => OmniEspace.xxxl,
    };

    // Colonnes : jamais plus de 4, sinon les cartes deviennent trop étroites.
    final colonnes = switch (taille) {
      OmniTailleFenetre.compacte => 2,
      OmniTailleFenetre.moyenne => 3,
      OmniTailleFenetre.etendue => largeur >= 1200 ? 4 : 3,
    };

    return OmniMetriques(
      largeur: largeur,
      hauteur: hauteur,
      taille: taille,
      marge: marge,
      largeurContenuMax: switch (taille) {
        OmniTailleFenetre.compacte => double.infinity,
        OmniTailleFenetre.moyenne => 560,
        OmniTailleFenetre.etendue => 720,
      },
      colonnes: colonnes,
      echelleTexte: donnees.textScaler.scale(1),
      paddingBas: donnees.viewPadding.bottom,
      paddingHaut: donnees.viewPadding.top,
      // Flutter expose la hauteur occupée par le clavier via viewInsets.
      clavierOuvert: donnees.viewInsets.bottom > 80,
    );
  }

  @override
  Widget build(BuildContext context) {
    final espace = depuis(MediaQuery.of(context));
    return _OmniResponsiveHerite(espace: espace, child: child);
  }
}

class _OmniResponsiveHerite extends InheritedWidget {
  const _OmniResponsiveHerite({required this.espace, required super.child});

  final OmniMetriques espace;

  @override
  bool updateShouldNotify(_OmniResponsiveHerite ancien) =>
      espace.largeur != ancien.espace.largeur ||
      espace.hauteur != ancien.espace.hauteur ||
      espace.echelleTexte != ancien.espace.echelleTexte ||
      espace.clavierOuvert != ancien.espace.clavierOuvert;
}

/// Contrainte un bloc de contenu à une largeur lisible et le centre sur les
/// grands écrans.
///
/// Sur téléphone, le contenu occupe toute la largeur. Sur tablette ou
/// pliable, il est plafonné à [largeurMax] et centré — une ligne de texte
/// trop longue fatigue la lecture.
class OmniContenuCentre extends StatelessWidget {
  const OmniContenuCentre({
    super.key,
    required this.child,
    this.largeurMax,
    this.padding,
  });

  final Widget child;
  final double? largeurMax;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final espace = OmniResponsive.maybeOf(context);
    final max = largeurMax ?? espace?.largeurContenuMax ?? double.infinity;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(horizontal: espace?.marge ?? 16),
          child: child,
        ),
      ),
    );
  }
}

/// Applique une échelle de texte bornée à un sous-arbre.
///
/// L'échelle système est respectée (accessibilité) mais bornée : au-delà de
/// [max], les libellés courts (badges, horodatages, coches) sortent de leur
/// conteneur et cassent la mise en page. Le bornage protège la géométrie
/// sans empêcher l'agrandissement — la valeur par défaut de 1,5 couvre déjà
/// le réglage « très grand » d'Android et d'iOS.
class OmniTexteBorne extends StatelessWidget {
  const OmniTexteBorne({
    super.key,
    required this.child,
    this.min = 0.85,
    this.max = 1.5,
  });

  final Widget child;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    final actuel = MediaQuery.textScalerOf(context).scale(1);
    if (actuel <= max && actuel >= min) return child;

    final borne = actuel.clamp(min, max);
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(borne)),
      child: child,
    );
  }
}
