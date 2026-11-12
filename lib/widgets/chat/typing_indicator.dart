import 'package:flutter/material.dart';

import '../../theme/omni_design.dart';
import '../../theme/omni_motion.dart';

/// Indicateur « en train d'écrire ».
///
/// Deux précautions, l'une visuelle et l'une de performance.
///
/// **Visuelle :** l'indicateur ne doit pas surgir d'un coup. Quand il
/// apparaît, il pousse le contenu de la conversation vers le haut ; une
/// apparition instantanée donne l'impression d'un à-coup. Il entre donc en
/// glissant et en s'estompant.
///
/// **Performance :** l'animation des trois points tourne en boucle, donc
/// indéfiniment. Le contrôleur est arrêté dès que l'indicateur est masqué —
/// sinon une minuterie continue de battre pour un widget invisible.
class TypingIndicator extends StatefulWidget {
  final bool show;

  const TypingIndicator({super.key, this.show = true});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    if (widget.show) _controller.repeat();
  }

  @override
  void didUpdateWidget(TypingIndicator ancien) {
    super.didUpdateWidget(ancien);
    if (widget.show && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.show && _controller.isAnimating) {
      // Arrêt net : sans cela la minuterie continue alors que rien n'est
      // affiché, et les tests signalent une minuterie en attente.
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);

    // Réduction de mouvement : l'état est tout de même indiqué, mais sans
    // animation — c'est une information, pas un décor.
    final reduit = OmniMouvement.animationsReduites(context);

    return AnimatedSize(
      duration: OmniMouvement.rapide,
      curve: OmniMouvement.standard,
      alignment: Alignment.topCenter,
      child: widget.show
          ? OmniApparition(
              distance: 8,
              duree: OmniMouvement.court,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniEspace.l,
                  vertical: OmniEspace.s,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: c.degradeAccent,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: OmniEspace.s),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: OmniEspace.l,
                        vertical: OmniEspace.m,
                      ),
                      decoration: BoxDecoration(
                        color: c.bulleEntrante,
                        borderRadius: OmniRayon.bulleEntrante,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          if (reduit) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: OmniEspace.xxs,
                              ),
                              child: _Point(couleur: c.texteSecondaire),
                            );
                          }
                          return AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              // Chaque point est décalé d'un cinquième de
                              // cycle : la vague qui en résulte est ce qui
                              // rend l'indicateur lisible comme « en train
                              // d'écrire » plutôt que comme trois points.
                              final retard = index * 0.2;
                              final valeur =
                                  (_controller.value - retard + 1.0) % 1.0;
                              final echelle =
                                  1.0 - (valeur * 0.5).clamp(0.0, 0.5);
                              final opacite =
                                  (1.0 - valeur).clamp(0.35, 1.0);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: OmniEspace.xxs,
                                ),
                                child: Transform.scale(
                                  scale: echelle,
                                  child: Opacity(
                                    opacity: opacite,
                                    child: _Point(couleur: c.texteSecondaire),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.couleur});

  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
    );
  }
}
