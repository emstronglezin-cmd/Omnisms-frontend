import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve, Cubic;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'omni_design.dart';

/// Composants de mouvement OmniSMS V3.
///
/// Règle de conception interne : **chaque animation doit soit guider
/// l'attention, soit confirmer une action, soit masquer une attente.** Un
/// effet qui ne fait aucun des trois n'est pas ajouté.
///
/// Deux garde-fous sont appliqués partout :
/// * les animations sont désactivées si l'utilisateur a activé
///   « animations réduites » dans les réglages du téléphone ;
/// * elles sont désactivables globalement dans les tests
///   ([OmniMouvementTest.desactivees]), sinon `pumpAndSettle` ne converge pas.

// ─── Courbes de ressort ────────────────────────────────────────────────────

/// Approximations cubiques des [SpringDescription] du design system.
///
/// Flutter n'expose pas de courbe de ressort utilisable par les widgets
/// d'animation implicite. Pour les amplitudes modestes employées ici
/// (échelle de 0,96 à 1, translation de 8 à 24 dp) une cubique calibrée est
/// visuellement indiscernable d'un vrai ressort, et ne coûte pas un
/// [AnimationController] par élément animé — ce qui compte quand une liste
/// de conversations en affiche une quinzaine.
abstract final class OmniCourbes {
  /// Reprise de [OmniMouvement.ressortCourt] : claquement net.
  static const Curve court = Cubic(0.34, 1.26, 0.64, 1.0);

  /// Reprise de [OmniMouvement.ressortMoyen] : léger rebond.
  static const Curve moyen = Cubic(0.34, 1.18, 0.64, 1.0);

  /// Reprise de [OmniMouvement.ressortLong] : ample.
  static const Curve long = Cubic(0.22, 1.12, 0.36, 1.0);
}

/// Coupe-circuit global pour les tests de widgets.
abstract final class OmniMouvementTest {
  /// Vrai si les animations sont court-circuitées.
  ///
  /// À remettre à `false` dans un `tearDown`, sinon les tests suivants
  /// héritent du réglage.
  static bool desactivees = false;
}

/// Durée effective : zéro si les animations sont réduites ou coupées en test.
Duration _dureeEffective(BuildContext context, Duration souhaitee) {
  if (OmniMouvementTest.desactivees) return Duration.zero;
  return OmniMouvement.duree(context, souhaitee);
}

// ─── Apparition ────────────────────────────────────────────────────────────

/// Apparition en fondu avec léger glissement vertical.
///
/// Sert à rythmer l'arrivée du contenu : l'œil suit le mouvement descendant
/// et comprend que l'écran se construit, plutôt que de voir un bloc figé
/// apparaître d'un coup. Le déplacement reste faible (12 dp) pour ne pas
/// donner l'impression de lenteur.
class OmniApparition extends StatefulWidget {
  const OmniApparition({
    super.key,
    required this.child,
    this.delai = Duration.zero,
    this.distance = 12,
    this.duree = OmniMouvement.entree,
    this.courbe = OmniMouvement.arrivee,
    this.horizontal = false,
  });

  final Widget child;

  /// Décalage avant le début. Utilisé pour les apparitions en cascade.
  final Duration delai;

  /// Amplitude du glissement, en dp.
  final double distance;

  final Duration duree;
  final Curve courbe;

  /// Glisse horizontalement au lieu de verticalement.
  final bool horizontal;

  @override
  State<OmniApparition> createState() => _OmniApparitionState();
}

class _OmniApparitionState extends State<OmniApparition> {
  @override
  Widget build(BuildContext context) {
    final duree = _dureeEffective(context, widget.duree);

    // Aucune animation : on affiche directement l'état final. C'est aussi ce
    // qui rend les tests déterministes.
    if (duree == Duration.zero) {
      return widget.child;
    }

    // Le délai est intégré à la courbe, **pas** à un Future.delayed.
    // Un `Future.delayed` dans `initState` laisse un Timer en attente si
    // l'élément est détruit avant son échéance (défilement rapide d'une
    // liste, fermeture d'écran) : le framework de test le signale comme une
    // fuite et, en production, il réveille un `State` démonté. Une courbe à
    // retard produit exactement le même rendu sans aucun timer.
    final total = duree + widget.delai;
    final fraction = total.inMicroseconds == 0
        ? 0.0
        : widget.delai.inMicroseconds / total.inMicroseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      curve: _CourbeAvecDelai(
        fractionDelai: fraction,
        courbe: widget.courbe,
      ),
      builder: (context, valeur, child) {
        final v = valeur.clamp(0.0, 1.0);
        final decalage = (1 - v) * widget.distance;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: widget.horizontal
                ? Offset(decalage, 0)
                : Offset(0, decalage),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Courbe qui reste à 0 pendant [fractionDelai] du temps, puis applique
/// [courbe] sur le reste.
///
/// C'est ainsi que l'on décale une animation sans créer de minuteur :
/// toute la temporisation vit dans la courbe, donc dans l'animation, donc
/// elle est annulée proprement avec le widget.
class _CourbeAvecDelai extends Curve {
  const _CourbeAvecDelai({required this.fractionDelai, required this.courbe});

  final double fractionDelai;
  final Curve courbe;

  @override
  double transform(double t) {
    if (fractionDelai <= 0) return courbe.transform(t);
    if (t <= fractionDelai) return 0;
    final local = ((t - fractionDelai) / (1 - fractionDelai)).clamp(0.0, 1.0);
    return courbe.transform(local);
  }
}

// ─── Apparition en cascade ─────────────────────────────────────────────────

/// Enveloppe un élément de liste pour une apparition en cascade.
///
/// **Garde-fou de performance** : le décalage est plafonné. Sans ce plafond,
/// le quarantième élément d'une longue liste attendrait plus d'une seconde
/// avant d'apparaître — une cascade qui se transforme en lenteur. Au-delà de
/// [indiceMax], tous les éléments apparaissent ensemble.
class OmniApparitionEspacee extends StatelessWidget {
  const OmniApparitionEspacee({
    super.key,
    required this.index,
    required this.child,
    this.pas = const Duration(milliseconds: 28),
    this.indiceMax = 12,
  });

  final int index;
  final Widget child;

  /// Décalage entre deux éléments consécutifs.
  final Duration pas;

  /// Au-delà de cet index, plus de décalage supplémentaire.
  final int indiceMax;

  @override
  Widget build(BuildContext context) {
    final borne = math.min(index, indiceMax);
    return OmniApparition(
      delai: pas * borne,
      duree: OmniMouvement.entree,
      child: child,
    );
  }
}

// ─── Retour au toucher ─────────────────────────────────────────────────────

/// Pression : l'élément se contracte très légèrement sous le doigt.
///
/// C'est la micro-interaction la plus rentable d'une application de
/// messagerie : elle confirme que l'appui a bien été pris, instantanément,
/// avant même que l'action ne s'exécute. L'amplitude est volontairement
/// faible (4 %) — perceptible, jamais distrayante.
class OmniPression extends StatefulWidget {
  const OmniPression({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.echelle = 0.96,
    this.haptique = true,
    this.actif = true,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Échelle au toucher (0,96 = contraction de 4 %).
  final double echelle;

  /// Retour haptique léger au toucher.
  final bool haptique;

  /// `false` désactive la micro-interaction (état désactivé, chargement).
  final bool actif;

  final BorderRadius? borderRadius;

  @override
  State<OmniPression> createState() => _OmniPressionState();
}

class _OmniPressionState extends State<OmniPression> {
  bool _appuye = false;

  void _majAppui(bool valeur) {
    if (!widget.actif || _appuye == valeur) return;
    setState(() => _appuye = valeur);
  }

  /// Retour haptique **au moment de l'activation**, pas à l'appui.
  ///
  /// Déclencher la vibration sur `onTapDown` ferait vibrer le téléphone à
  /// chaque début de défilement — le geste de scroll commence toujours par
  /// un appui. On attend donc que le geste soit confirmé comme un appui.
  void _action() {
    if (!widget.actif) return;
    if (widget.haptique) HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final duree = _dureeEffective(context, OmniMouvement.instantane);
    final cible = _appuye && widget.actif ? widget.echelle : 1.0;

    Widget contenu = widget.child;

    if (duree != Duration.zero) {
      contenu = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: cible),
        duration: duree,
        curve: OmniCourbes.court,
        builder: (context, valeur, child) =>
            Transform.scale(scale: valeur, child: child),
        child: contenu,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.actif ? _action : null,
      onLongPress: widget.actif ? widget.onLongPress : null,
      onTapDown: widget.actif ? (_) => _majAppui(true) : null,
      onTapUp: widget.actif ? (_) => _majAppui(false) : null,
      onTapCancel: widget.actif ? () => _majAppui(false) : null,
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: contenu,
      ),
    );
  }
}

// ─── Squelette de chargement ───────────────────────────────────────────────

/// Squelette animé (effet de balayage) pour les états de chargement.
///
/// Un écran qui se charge doit montrer **la forme** de ce qui va arriver,
/// pas un cercle tournant : l'utilisateur sait ainsi où regarder et perçoit
/// l'attente comme plus courte.
class OmniSquelette extends StatefulWidget {
  const OmniSquelette({
    super.key,
    this.largeur,
    this.hauteur = 16,
    this.rayon = OmniRayon.xs,
  });

  final double? largeur;
  final double hauteur;
  final double rayon;

  @override
  State<OmniSquelette> createState() => _OmniSqueletteState();
}

class _OmniSqueletteState extends State<OmniSquelette>
    with SingleTickerProviderStateMixin {
  AnimationController? _controleur;

  @override
  void initState() {
    super.initState();
    if (!OmniMouvementTest.desactivees) {
      _controleur = AnimationController(
        vsync: this,
        duration: OmniMouvement.squelette,
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controleur?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = OmniCouleurs.of(context);
    final base = couleurs.surfaceVariante;

    Widget bloc = Container(
      width: widget.largeur,
      height: widget.hauteur,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(widget.rayon),
      ),
    );

    // Sans contrôleur (animations réduites ou test) : surface unie. La forme
    // reste annoncée, seul le balayage disparaît.
    final controleur = _controleur;
    if (controleur == null) return bloc;

    return AnimatedBuilder(
      animation: controleur,
      builder: (context, child) {
        return Container(
          width: widget.largeur,
          height: widget.hauteur,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.rayon),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              // Le reflet parcourt le bloc : -1 → 2 pour que la zone claire
              // entre et sorte complètement.
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              colors: [
                base,
                base,
                base.withValues(alpha: 0.55),
                base,
                base,
              ],
              transform: _Balayage(controleur.value * 3 - 1),
            ),
          ),
        );
      },
    );
  }
}

/// Décale un dégradé sans le déformer, pour l'effet de balayage.
class _Balayage extends GradientTransform {
  const _Balayage(this.decalage);

  final double decalage;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(decalage * bounds.width, 0, 0);
  }
}

// ─── Transitions d'écran ───────────────────────────────────────────────────

/// Route de page animée selon la grammaire de Material 3.
///
/// Trois variantes seulement, chacune avec une signification :
/// * [axePartage] : l'écran pousse le précédent (navigation avant/arrière
///   dans une hiérarchie) — utilisé pour ouvrir une conversation ;
/// * [fondu] : l'écran se substitue sans lien spatial — utilisé pour les
///   parcours d'authentification et les écrans plein écran ;
/// * [glissementBas] : l'écran monte du bas (feuilles, modales).
enum OmniTypeTransition { axePartage, fondu, glissementBas }

/// [PageRoute] animée, remplacement de `MaterialPageRoute` dans les écrans
/// V3. Les durées et courbes viennent du design system.
class OmniRoute<T> extends PageRouteBuilder<T> {
  OmniRoute({
    required this.builder,
    this.type = OmniTypeTransition.axePartage,
    super.settings,
  }) : super(
          transitionDuration: switch (type) {
            OmniTypeTransition.axePartage => OmniMouvement.long,
            OmniTypeTransition.fondu => OmniMouvement.moyen,
            OmniTypeTransition.glissementBas => OmniMouvement.entree,
          },
          reverseTransitionDuration: switch (type) {
            OmniTypeTransition.axePartage => OmniMouvement.moyen,
            OmniTypeTransition.fondu => OmniMouvement.sortie,
            OmniTypeTransition.glissementBas => OmniMouvement.sortie,
          },
          pageBuilder: (context, animation, secondaire) => builder(context),
          transitionsBuilder: (context, animation, secondaire, child) {
            return _construireTransition(
              type,
              animation,
              secondaire,
              child,
            );
          },
        );

  final WidgetBuilder builder;
  final OmniTypeTransition type;

  static Widget _construireTransition(
    OmniTypeTransition type,
    Animation<double> animation,
    Animation<double> secondaire,
    Widget child,
  ) {
    switch (type) {
      case OmniTypeTransition.axePartage:
        // L'écran entrant avance et monte légèrement ; le sortant recule à
        // moitié. Ce demi-décalage est ce qui donne la sensation de
        // profondeur sans obscurcir l'écran qui s'en va.
        final entrant = CurvedAnimation(
          parent: animation,
          curve: OmniMouvement.arrivee,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0.02),
            end: Offset.zero,
          ).animate(entrant),
          child: FadeTransition(
            opacity: entrant,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-0.04, 0),
              ).animate(
                CurvedAnimation(
                  parent: secondaire,
                  curve: OmniMouvement.standard,
                ),
              ),
              child: child,
            ),
          ),
        );

      case OmniTypeTransition.fondu:
        // Fondu croisé avec une très légère montée : l'écran « apparaît »
        // plutôt qu'il ne « saute ».
        final courbe = CurvedAnimation(
          parent: animation,
          curve: OmniMouvement.arrivee,
        );
        return FadeTransition(
          opacity: courbe,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(courbe),
            child: child,
          ),
        );

      case OmniTypeTransition.glissementBas:
        final courbe = CurvedAnimation(
          parent: animation,
          curve: OmniMouvement.arrivee,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(courbe),
          child: FadeTransition(opacity: courbe, child: child),
        );
    }
  }
}

// ─── Compteur animé ────────────────────────────────────────────────────────

/// Nombre qui s'incrémente en animation.
///
/// Utilisé pour les compteurs (messages, crédits, statistiques). Le
/// mouvement attire l'œil sur une valeur qui vient de changer — c'est une
/// animation qui **informe**, pas une décoration.
class OmniCompteurAnime extends StatelessWidget {
  const OmniCompteurAnime({
    super.key,
    required this.valeur,
    required this.style,
    this.duree = OmniMouvement.moyen,
  });

  final int valeur;
  final TextStyle style;
  final Duration duree;

  @override
  Widget build(BuildContext context) {
    final dureeEffective = _dureeEffective(context, duree);

    if (dureeEffective == Duration.zero) {
      return Text('$valeur', style: style);
    }

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: valeur),
      duration: dureeEffective,
      curve: OmniMouvement.arrivee,
      builder: (context, valeurAnimee, _) =>
          Text('$valeurAnimee', style: style),
    );
  }
}
