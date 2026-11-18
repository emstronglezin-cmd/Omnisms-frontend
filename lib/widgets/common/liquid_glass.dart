/// OmniSMS — bibliothèque de surfaces : profondeur, verre, aurore.
///
/// Issue de la v5.1 « Liquid Glass », réécrite pour lire les jetons de la
/// variante courante : les mêmes composants rendent donc l'identité Classique
/// ou l'identité Nova sans qu'aucun écran n'ait à le savoir.
///
/// Deux règles guident tout ce fichier.
///
/// 1. **Le verre est chirurgical.** Le flou n'a de sens que sur une couche qui
///    recouvre du contenu encore visible : barre de navigation, en-tête qui
///    défile, champ de saisie, feuille modale, carte d'action. Sur un fond
///    plein il ne renseigne sur rien et coûte cher à chaque image. Le contenu
///    courant vit donc sur des plans opaques ([OmniCarte]).
///
/// 2. **La profondeur vient des plans, pas des ombres.** En thème sombre une
///    ombre portée est invisible ; ce qui sépare deux niveaux, c'est un fond
///    plus clair et un liseré d'un pixel. Cinq plans sont définis dans
///    [OmniCouleurs], du plus éloigné ([OmniCouleurs.planFond]) au plus proche
///    ([OmniCouleurs.planFlottant]).
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/omni_design.dart';
import '../../theme/omni_motion.dart';
import 'avatar_image.dart';

// ─── Fond aurore ──────────────────────────────────────────────────────────────
/// Halos posés derrière le contenu d'un écran.
///
/// Ce n'est pas une décoration animée : aucun `AnimationController`, donc aucun
/// coût par image. Les halos sont dessinés une fois et donnent à un fond sombre
/// la profondeur qui lui manque autrement — un fond uniformément noir aplati
/// l'interface et fait disparaître la hiérarchie.
class OmniFondAurore extends StatelessWidget {
  const OmniFondAurore({
    super.key,
    required this.child,
    this.intensite = 1.0,
    this.alignement = AlignmentHautGauche,
  });

  final Widget child;

  /// 0 = fond uni, 1 = halos pleins. À baisser sur les écrans denses en texte,
  /// où un fond mouvementé gêne la lecture.
  final double intensite;

  final _AlignementAurore alignement;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final jetons = Theme.of(context).extension<OmniJetons>();
    final nova = c.estNova;

    // En Classique il n'y a PAS d'aurore du tout : l'identité d'origine est
    // conservée telle quelle, c'est la condition du retour arrière.
    final force = intensite * (nova ? 1.0 : 0.0);

    return DecoratedBox(
      decoration: BoxDecoration(color: c.planFond),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (force > 0)
            IgnorePointer(
              child: CustomPaint(
                painter: _PeintreAurore(
                  couleur: c,
                  jetons: jetons,
                  force: force,
                  alignement: alignement,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Emplacements des halos. Le choix change la lecture de l'écran : un halo en
/// haut éclaire l'en-tête, un halo centré met le contenu en avant.
enum _AlignementAurore { hautGauche, hautDroite, centre, bas }

/// Alias lisibles pour l'API publique.
const AlignmentHautGauche = _AlignementAurore.hautGauche;
const AlignmentHautDroite = _AlignementAurore.hautDroite;
const AlignmentCentre = _AlignementAurore.centre;
const AlignmentBas = _AlignementAurore.bas;

class _PeintreAurore extends CustomPainter {
  _PeintreAurore({
    required this.couleur,
    required this.jetons,
    required this.force,
    required this.alignement,
  });

  final OmniCouleurs couleur;
  final OmniJetons? jetons;
  final double force;
  final _AlignementAurore alignement;

  @override
  void paint(Canvas canvas, Size size) {
    final sombre = couleur.estSombre;
    // En thème clair les halos doivent rester des teintes, pas des lumières :
    // un blanc sur blanc ne se voit pas, un accent saturé agresse.
    final opacite = sombre ? 0.22 * force : 0.11 * force;

    final trio = jetons?.estNova ?? false
        ? <Color>[
            OmniNovaPalette.cyan,
            OmniNovaPalette.indigo,
            OmniNovaPalette.magenta,
          ]
        : <Color>[couleur.accent, couleur.accentSecondaire, couleur.accent];

    final halos = switch (alignement) {
      _AlignementAurore.hautGauche => <_Halo>[
        _Halo(
          Offset(size.width * 0.06, -size.height * 0.06),
          size.width * 0.95,
          trio[0],
        ),
        _Halo(
          Offset(size.width * 0.88, size.height * 0.16),
          size.width * 0.62,
          trio[1],
        ),
        _Halo(
          Offset(size.width * 0.22, size.height * 0.86),
          size.width * 0.70,
          trio[2],
        ),
      ],
      _AlignementAurore.hautDroite => <_Halo>[
        _Halo(
          Offset(size.width * 0.94, -size.height * 0.06),
          size.width * 0.95,
          trio[0],
        ),
        _Halo(
          Offset(size.width * 0.10, size.height * 0.20),
          size.width * 0.60,
          trio[1],
        ),
        _Halo(
          Offset(size.width * 0.78, size.height * 0.88),
          size.width * 0.68,
          trio[2],
        ),
      ],
      _AlignementAurore.centre => <_Halo>[
        _Halo(
          Offset(size.width * 0.5, size.height * 0.34),
          size.width * 1.05,
          trio[0],
        ),
        _Halo(
          Offset(size.width * 0.08, size.height * 0.08),
          size.width * 0.55,
          trio[1],
        ),
        _Halo(
          Offset(size.width * 0.92, size.height * 0.72),
          size.width * 0.58,
          trio[2],
        ),
      ],
      _AlignementAurore.bas => <_Halo>[
        _Halo(
          Offset(size.width * 0.5, size.height * 1.02),
          size.width * 1.0,
          trio[0],
        ),
        _Halo(
          Offset(size.width * 0.10, size.height * 0.72),
          size.width * 0.55,
          trio[1],
        ),
        _Halo(
          Offset(size.width * 0.90, size.height * 0.40),
          size.width * 0.50,
          trio[2],
        ),
      ],
    };

    for (final h in halos) {
      final peinture = Paint()
        ..shader = RadialGradient(
          colors: [
            h.couleur.withValues(alpha: opacite),
            h.couleur.withValues(alpha: 0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: h.centre, radius: h.rayon));
      canvas.drawCircle(h.centre, h.rayon, peinture);
    }
  }

  @override
  bool shouldRepaint(_PeintreAurore ancien) =>
      ancien.force != force ||
      ancien.alignement != alignement ||
      ancien.couleur.fond != couleur.fond ||
      ancien.couleur.estNova != couleur.estNova;
}

class _Halo {
  const _Halo(this.centre, this.rayon, this.couleur);
  final Offset centre;
  final double rayon;
  final Color couleur;
}

// ─── Surface de verre ─────────────────────────────────────────────────────────
/// Couche de verre : flou du contenu situé dessous, remplissage translucide,
/// liseré d'un pixel et reflet interne.
///
/// À réserver aux éléments qui **recouvrent** du contenu. Pour une carte posée
/// sur le fond d'écran, utiliser [OmniCarte] : le flou n'y apporterait rien et
/// coûterait une passe de rendu supplémentaire.
class OmniVerre extends StatelessWidget {
  const OmniVerre({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.flou,
    this.fond,
    this.border,
    this.boxShadow,
    this.onTap,
    this.opacite = 1.0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  /// Null = valeur de la variante ([OmniCouleurs.verreFlou]).
  final double? flou;
  final Color? fond;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  /// < 1 pour un verre discret (en-tête qui défile), 1 pour une feuille modale.
  final double opacite;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final rayon = borderRadius ?? BorderRadius.circular(OmniRayon.l);
    final sigma = (flou ?? c.verreFlou) * opacite;

    Widget contenu = ClipRRect(
      borderRadius: rayon,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fond ?? c.verre,
            borderRadius: rayon,
            border: border ?? Border.all(color: c.verreContour, width: 1),
            gradient: c.verreReflet,
            boxShadow:
                boxShadow ??
                [
                  BoxShadow(
                    color: c.ombre,
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );

    if (onTap != null) {
      contenu = OmniPression(onTap: onTap, borderRadius: rayon, child: contenu);
    }

    return contenu;
  }
}

/// Nom conservé de la v5.1 : même rôle, rendu désormais piloté par la variante.
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blurStrength = 20.0,
    this.background,
    this.border,
    this.boxShadow,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blurStrength;
  final Color? background;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OmniVerre(
    child: child,
    padding: padding,
    borderRadius: borderRadius,
    flou: blurStrength,
    fond: background,
    border: border,
    boxShadow: boxShadow,
    onTap: onTap,
  );
}

// ─── Carte pleine ─────────────────────────────────────────────────────────────
/// Carte opaque posée sur un plan donné.
///
/// C'est la surface de travail par défaut : le contenu courant doit rester
/// parfaitement lisible, et une carte pleine coûte moins cher qu'un flou.
class OmniCarte extends StatelessWidget {
  const OmniCarte({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(OmniEspace.l),
    this.plan,
    this.borderRadius,
    this.onTap,
    this.onLongPress,
    this.accentuee = false,
    this.liser = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Plan de profondeur. Null = [OmniCouleurs.planCarte].
  final Color? plan;

  /// Vrai pour l'élément mis en avant : liseré d'accent et halo léger.
  final bool accentuee;

  final bool liser;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final rayon = borderRadius ?? BorderRadius.circular(OmniRayon.l);
    final fond = plan ?? c.planCarte;

    final carte = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fond,
        borderRadius: rayon,
        border: liser
            ? Border.all(
                color: accentuee ? c.accentContour : c.contour,
                width: 1,
              )
            : null,
        boxShadow: [
          if (accentuee)
            BoxShadow(
              color: c.lueur,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          if (c.estSombre == false)
            BoxShadow(
              color: c.ombre,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return carte;
    return OmniPression(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: rayon,
      child: carte,
    );
  }
}

// ─── En-tête ──────────────────────────────────────────────────────────────────
/// En-tête d'écran : titre, sous-titre optionnel, actions à droite.
///
/// Remplace les `AppBar` pleines. Il est transparent pour laisser passer le
/// fond aurore, ce qui est précisément ce qui donne l'impression de profondeur.
class OmniEntete extends StatelessWidget implements PreferredSizeWidget {
  const OmniEntete({
    super.key,
    required this.titre,
    this.sousTitre,
    this.actions,
    this.retour = false,
    this.onRetour,
    this.gradient = false,
    this.hauteur = kToolbarHeight + 12,
  });

  final String titre;
  final String? sousTitre;
  final List<Widget>? actions;
  final bool retour;
  final VoidCallback? onRetour;

  /// Titre peint dans le dégradé aurore. À réserver aux écrans d'arrivée.
  final bool gradient;

  final double hauteur;

  @override
  Size get preferredSize => Size.fromHeight(hauteur);

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: c.texte,
    );

    return SizedBox(
      height: hauteur,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OmniEspace.margeEcran),
        child: Row(
          children: [
            if (retour) ...[
              OmniPression(
                onTap: onRetour ?? () => Navigator.of(context).maybePop(),
                borderRadius: OmniRayon.pill,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.planEleve,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.contour),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: c.texte,
                  ),
                ),
              ),
              const SizedBox(width: OmniEspace.m),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (gradient)
                    OmniTexteGradient(texte: titre, style: style)
                  else
                    Text(
                      titre,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (sousTitre != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sousTitre!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: c.texteSecondaire),
                    ),
                  ],
                ],
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}

/// En-tête qui devient verre une fois le contenu défilé dessous.
///
/// Le flou n'apparaît que lorsqu'il y a quelque chose à flouter : c'est le cas
/// d'usage légitime du verre, et cela évite de payer un `BackdropFilter` sur un
/// écran qui ne défile pas.
class OmniEnteteVerre extends StatelessWidget implements PreferredSizeWidget {
  const OmniEnteteVerre({super.key, required this.entete});

  final OmniEntete entete;

  @override
  Size get preferredSize => entete.preferredSize;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.verreFlou, sigmaY: c.verreFlou),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.verreFlottant,
            border: Border(bottom: BorderSide(color: c.verreContour)),
          ),
          child: SafeArea(bottom: false, child: entete),
        ),
      ),
    );
  }
}

/// AppBar en verre. Nom conservé de la v5.1.
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LiquidGlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.verreFlou, sigmaY: c.verreFlou),
        child: AppBar(
          backgroundColor: c.verreFlottant,
          foregroundColor: c.texte,
          surfaceTintColor: Colors.transparent,
          title: Text(title),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          actions: actions,
          flexibleSpace: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.verreContour)),
              gradient: c.verreReflet,
            ),
          ),
          systemOverlayStyle: c.overlay,
        ),
      ),
    );
  }
}

// ─── Barre de navigation flottante ────────────────────────────────────────────
/// Barre d'onglets en verre, ancrée en bas et détachée des bords.
///
/// Deux raisons à cette forme. La pouce n'atteint pas le haut d'un écran de
/// 6,7 pouces : les actions principales appartiennent au tiers inférieur. Et
/// une barre détachée laisse voir le fond aurore passer dessous, ce qui est le
/// seul endroit de l'écran où le flou renseigne vraiment l'utilisateur.
class OmniBarreFlottante extends StatelessWidget {
  const OmniBarreFlottante({
    super.key,
    required this.onglets,
    required this.index,
    required this.onTap,
    this.etiquettes = true,
    this.inclureZoneSur = true,
  });

  final List<OmniOnglet> onglets;
  final int index;
  final ValueChanged<int> onTap;
  final bool etiquettes;

  /// Faux quand l'écran parent ajoute déjà la marge de zone sûre : Safari sur
  /// iPhone recouvre la barre, et c'est le parent qui connaît cette valeur.
  final bool inclureZoneSur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        OmniEspace.m,
        0,
        OmniEspace.m,
        OmniEspace.m +
            (inclureZoneSur ? MediaQuery.of(context).padding.bottom : 0),
      ),
      child: OmniVerre(
        borderRadius: BorderRadius.circular(OmniRayon.xl + 4),
        padding: const EdgeInsets.symmetric(
          horizontal: OmniEspace.xs,
          vertical: OmniEspace.xs,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < onglets.length; i++)
              Expanded(
                child: _OngletFlottant(
                  onglet: onglets[i],
                  actif: i == index,
                  etiquettes: etiquettes,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Description d'un onglet de [OmniBarreFlottante].
class OmniOnglet {
  const OmniOnglet({
    required this.icone,
    required this.libelle,
    this.iconeActive,
    this.badge = 0,
  });

  final IconData icone;
  final String libelle;
  final IconData? iconeActive;

  /// Nombre de notifications. 0 = pas de pastille.
  final int badge;
}

class _OngletFlottant extends StatelessWidget {
  const _OngletFlottant({
    required this.onglet,
    required this.actif,
    required this.etiquettes,
    required this.onTap,
  });

  final OmniOnglet onglet;
  final bool actif;
  final bool etiquettes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final jetons = Theme.of(context).extension<OmniJetons>();

    return OmniPression(
      onTap: actif ? null : onTap,
      echelle: 0.94,
      borderRadius: BorderRadius.circular(OmniRayon.l),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: OmniCourbes.moyen,
        padding: const EdgeInsets.symmetric(vertical: OmniEspace.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(OmniRayon.l),
          gradient: actif ? jetons?.degradeAurore : null,
          boxShadow: actif ? [BoxShadow(color: c.lueur, blurRadius: 14)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  actif ? (onglet.iconeActive ?? onglet.icone) : onglet.icone,
                  size: 22,
                  color: actif ? c.surAccent : c.texteEstompe,
                ),
                if (onglet.badge > 0)
                  Positioned(
                    right: -7,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: OmniPalette.erreur,
                        borderRadius: OmniRayon.pill,
                        border: Border.all(color: c.planFond, width: 1.5),
                      ),
                      child: Text(
                        onglet.badge > 99 ? '99+' : '${onglet.badge}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (etiquettes) ...[
              const SizedBox(height: 3),
              Text(
                onglet.libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                  color: actif ? c.surAccent : c.texteEstompe,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Typographie ──────────────────────────────────────────────────────────────
/// Texte peint dans le dégradé aurore de la variante courante.
class OmniTexteGradient extends StatelessWidget {
  const OmniTexteGradient({super.key, required this.texte, this.style});

  final String texte;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    return ShaderMask(
      shaderCallback: (bornes) => c.degradeAurore.createShader(
        Rect.fromLTWH(0, 0, bornes.width, bornes.height),
      ),
      child: Text(
        texte,
        style:
            (style ??
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))
                .copyWith(color: Colors.white),
      ),
    );
  }
}

/// Nom conservé de la v5.1.
class OmniGradientText extends StatelessWidget {
  const OmniGradientText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      OmniTexteGradient(texte: text, style: style);
}

// ─── Avatar ───────────────────────────────────────────────────────────────────
/// Avatar cerclé d'un dégradé, avec pastille de présence réelle.
class OmniAvatarWidget extends StatelessWidget {
  const OmniAvatarWidget({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = 44,
    this.showOnlineDot = false,
    this.enLigne,
    this.groupe = false,
  });

  final String? imageUrl;
  final String? initials;
  final double size;

  /// Null = ne pas afficher de pastille. Vrai/faux = état réellement connu.
  /// Jamais inventé : une présence simulée est un mensonge affiché à
  /// l'utilisateur.
  final bool? enLigne;
  final bool showOnlineDot;
  final bool groupe;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final jetons = Theme.of(context).extension<OmniJetons>();
    final afficherPastille = enLigne ?? (showOnlineDot ? true : null);

    final Widget avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size > 40 ? 2 : 1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: jetons?.degradeAurore ?? c.degradeAurore,
        boxShadow: c.estNova
            ? [BoxShadow(color: c.lueur, blurRadius: size * 0.28)]
            : null,
      ),
      child: ClipOval(
        child: UserAvatar(
          imageUrl: imageUrl,
          name: initials ?? '',
          size: size,
          isGroup: groupe,
          fallback: _initiales(c),
        ),
      ),
    );

    if (afficherPastille == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(
              color: afficherPastille ? OmniPalette.succes : c.texteEstompe,
              shape: BoxShape.circle,
              border: Border.all(color: c.planFond, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initiales(OmniCouleurs c) {
    final brut = (initials ?? '?').trim();
    final lettres = brut.isEmpty
        ? '?'
        : brut.substring(0, brut.length > 1 ? 2 : 1);
    return Container(
      width: size,
      height: size,
      color: c.planEleve,
      alignment: Alignment.center,
      child: Text(
        lettres.toUpperCase(),
        style: TextStyle(
          color: c.texte,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Boutons ──────────────────────────────────────────────────────────────────
/// Action principale : dégradé aurore, halo, retour haptique.
class OmniGradientButton extends StatefulWidget {
  const OmniGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.elargi = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool elargi;

  @override
  State<OmniGradientButton> createState() => _OmniGradientButtonState();
}

class _OmniGradientButtonState extends State<OmniGradientButton> {
  bool _enfonce = false;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final jetons = Theme.of(context).extension<OmniJetons>();
    final actif = widget.onPressed != null && !widget.isLoading;

    return Semantics(
      button: true,
      enabled: actif,
      label: widget.label,
      child: GestureDetector(
        onTapDown: actif ? (_) => setState(() => _enfonce = true) : null,
        onTapCancel: actif ? () => setState(() => _enfonce = false) : null,
        onTapUp: actif ? (_) => setState(() => _enfonce = false) : null,
        onTap: actif
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _enfonce ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: OmniCourbes.court,
          child: AnimatedOpacity(
            opacity: actif ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 150),
            child: Container(
              width: widget.elargi ? double.infinity : null,
              height: 52,
              padding: widget.elargi
                  ? null
                  : const EdgeInsets.symmetric(horizontal: OmniEspace.xl),
              decoration: BoxDecoration(
                gradient: actif
                    ? (jetons?.degradeAurore ?? c.degradeAurore)
                    : null,
                color: actif ? null : c.planEleve,
                borderRadius: BorderRadius.circular(OmniRayon.m),
                border: actif ? null : Border.all(color: c.contour),
                boxShadow: actif
                    ? [
                        BoxShadow(
                          color: c.lueur,
                          blurRadius: _enfonce ? 10 : 18,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            c.surAccent,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: c.surAccent, size: 18),
                            const SizedBox(width: OmniEspace.s),
                          ],
                          Flexible(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.surAccent,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.01,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Action secondaire : verre, sans dégradé. Ne rivalise pas avec la principale.
class OmniBoutonVerre extends StatelessWidget {
  const OmniBoutonVerre({
    super.key,
    required this.libelle,
    this.onPressed,
    this.icone,
    this.elargi = true,
  });

  final String libelle;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool elargi;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final actif = onPressed != null;

    return OmniPression(
      onTap: onPressed,
      actif: actif,
      borderRadius: BorderRadius.circular(OmniRayon.m),
      child: Opacity(
        opacity: actif ? 1.0 : 0.45,
        child: Container(
          width: elargi ? double.infinity : null,
          height: 52,
          padding: elargi
              ? null
              : const EdgeInsets.symmetric(horizontal: OmniEspace.xl),
          decoration: BoxDecoration(
            color: c.planEleve,
            borderRadius: BorderRadius.circular(OmniRayon.m),
            border: Border.all(color: c.contour),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 18, color: c.texte),
                const SizedBox(width: OmniEspace.s),
              ],
              Text(
                libelle,
                style: TextStyle(
                  color: c.texte,
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

// ─── Puce ─────────────────────────────────────────────────────────────────────
/// Étiquette courte : filtre, statut, catégorie.
class OmniPuce extends StatelessWidget {
  const OmniPuce({
    super.key,
    required this.libelle,
    this.icone,
    this.active = false,
    this.couleur,
    this.onTap,
  });

  final String libelle;
  final IconData? icone;
  final bool active;

  /// Null = accent de la variante. À renseigner pour un statut sémantique.
  final Color? couleur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final teinte = couleur ?? c.accent;

    final puce = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniEspace.m,
        vertical: OmniEspace.s - 1,
      ),
      decoration: BoxDecoration(
        color: active ? teinte.withValues(alpha: 0.18) : c.planEleve,
        borderRadius: OmniRayon.pill,
        border: Border.all(
          color: active ? teinte.withValues(alpha: 0.55) : c.contour,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 14, color: active ? teinte : c.texteSecondaire),
            const SizedBox(width: OmniEspace.xs + 2),
          ],
          Text(
            libelle,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.2,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? teinte : c.texteSecondaire,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return puce;
    return OmniPression(
      onTap: onTap,
      echelle: 0.95,
      borderRadius: OmniRayon.pill,
      child: puce,
    );
  }
}

// ─── Bulle de message ─────────────────────────────────────────────────────────
/// Bulle de message : sortante en dégradé plein, entrante en verre.
///
/// L'asymétrie des rayons indique la direction sans qu'un libellé soit
/// nécessaire : le coin resserré est du côté de l'expéditeur.
class OmniMessageBubble extends StatelessWidget {
  const OmniMessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    this.time,
    this.senderName,
  });

  final String text;
  final bool isMe;
  final String? time;
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        child: isMe ? _sortante(context) : _entrante(context),
      ),
    );
  }

  Widget _sortante(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final jetons = Theme.of(context).extension<OmniJetons>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        gradient: jetons?.degradeAurore ?? c.degradeAurore,
        borderRadius: OmniRayon.bulleSortante,
        boxShadow: [
          BoxShadow(color: c.lueur, blurRadius: 14, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            text,
            style: TextStyle(color: c.surAccent, fontSize: 14.5, height: 1.45),
          ),
          if (time != null) ...[
            const SizedBox(height: 3),
            Text(
              time!,
              style: TextStyle(
                color: c.surAccent.withValues(alpha: 0.78),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _entrante(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final rayon = OmniRayon.bulleEntrante;

    return ClipRRect(
      borderRadius: rayon,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: c.verre,
            borderRadius: rayon,
            border: Border.all(color: c.verreContour),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (senderName != null) ...[
                Text(
                  senderName!,
                  style: TextStyle(
                    color: c.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                text,
                style: TextStyle(color: c.texte, fontSize: 14.5, height: 1.45),
              ),
              if (time != null) ...[
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    time!,
                    style: TextStyle(color: c.texteSecondaire, fontSize: 11),
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

// ─── Champ de saisie ──────────────────────────────────────────────────────────
/// Décoration de champ cohérente avec le reste de l'identité.
///
/// Fournie comme `InputDecoration` plutôt que comme widget : les écrans
/// gardent leur `TextFormField` existant et n'ont qu'à remplacer la décoration.
class OmniChamp {
  OmniChamp._();

  static InputDecoration decoration(
    BuildContext context, {
    String? etiquette,
    String? indice,
    String? aide,
    String? erreur,
    IconData? icone,
    Widget? suffixe,
    int lignes = 1,
  }) {
    final c = OmniCouleurs.of(context);
    final rayon = BorderRadius.circular(OmniRayon.m);

    return InputDecoration(
      labelText: etiquette,
      hintText: indice,
      helperText: aide,
      errorText: erreur,
      prefixIcon: icone == null
          ? null
          : Icon(
              icone,
              size: 20,
              color: erreur != null ? OmniPalette.erreur : c.texteSecondaire,
            ),
      suffixIcon: suffixe,
      filled: true,
      fillColor: erreur != null
          ? OmniPalette.erreur.withValues(alpha: 0.07)
          : c.planEleve,
      contentPadding: EdgeInsets.symmetric(
        horizontal: OmniEspace.l,
        vertical: lignes > 1 ? OmniEspace.m : OmniEspace.l - 1,
      ),
      border: OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: c.contour),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: c.contour),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: c.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: rayon,
        borderSide: const BorderSide(color: OmniPalette.erreur),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: rayon,
        borderSide: const BorderSide(color: OmniPalette.erreur, width: 1.6),
      ),
      labelStyle: TextStyle(color: c.texteSecondaire),
      hintStyle: TextStyle(color: c.texteEstompe),
      helperStyle: TextStyle(color: c.texteEstompe, fontSize: 12),
      errorStyle: const TextStyle(color: OmniPalette.erreur, fontSize: 12),
    );
  }
}
