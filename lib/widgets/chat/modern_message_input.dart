import 'package:flutter/material.dart';

import '../../theme/omni_design.dart';
import '../../theme/omni_motion.dart';

/// Barre de saisie d'un message.
///
/// Le point central de cet écran est le bouton à droite : il est **micro**
/// quand le champ est vide et **envoyer** dès qu'un texte est saisi. Changer
/// la fonction d'un bouton sans le montrer est une source d'erreur classique
/// — l'utilisateur appuie en croyant dicter et envoie un message vide, ou
/// l'inverse. Le bouton **morphe** donc : rotation, fondu et léger
/// redimensionnement, pour que le changement de rôle soit visible avant
/// l'appui.
class ModernMessageInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onStartRecording;
  final VoidCallback? onAttachment;

  const ModernMessageInput({
    super.key,
    required this.onSendMessage,
    this.onStartRecording,
    this.onAttachment,
  });

  @override
  State<ModernMessageInput> createState() => _ModernMessageInputState();
}

class _ModernMessageInputState extends State<ModernMessageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_surveillerTexte);
    _focus.addListener(() => setState(() {}));
  }

  void _surveillerTexte() {
    final nouveau = _controller.text.trim().isNotEmpty;
    if (nouveau != _hasText) setState(() => _hasText = nouveau);
  }

  @override
  void dispose() {
    _controller.removeListener(_surveillerTexte);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    debugPrint('[DEBUG_SEND] ModernMessageInput _handleSend pressed, '
        'hasText=$_hasText, textLen=${text.length}, content=$text');
    if (text.isNotEmpty) {
      debugPrint('[DEBUG_SEND] ModernMessageInput calling onSendMessage');
      widget.onSendMessage(text);
      _controller.clear();
      setState(() => _hasText = false);
    } else {
      debugPrint('[DEBUG_SEND] ModernMessageInput empty text, abort');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniEspace.s,
        vertical: OmniEspace.s,
      ),
      decoration: BoxDecoration(
        color: c.fond,
        border: Border(top: BorderSide(color: c.contour)),
        boxShadow: [
          BoxShadow(
            color: c.ombre.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Bouton d'ajout ──────────────────────────────────────
            OmniPression(
              borderRadius: OmniRayon.pill,
              onTap: widget.onAttachment,
              actif: widget.onAttachment != null,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  color: widget.onAttachment != null ? c.accent : c.texteEstompe,
                  size: 26,
                ),
              ),
            ),

            // ── Champ de saisie ─────────────────────────────────────
            Expanded(
              child: AnimatedContainer(
                duration: OmniMouvement.rapide,
                curve: OmniMouvement.standard,
                decoration: BoxDecoration(
                  color: c.surfaceVariante,
                  // Le champ se creuse légèrement quand il est actif :
                  // c'est le seul indice qui indique où le texte ira.
                  borderRadius: OmniRayon.champ,
                  border: Border.all(
                    color: _focus.hasFocus ? c.accentContour : c.contour,
                    width: _focus.hasFocus ? 1.5 : 1,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    hintStyle: OmniTypo.corps
                        .copyWith(color: c.texteEstompe),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: OmniEspace.m,
                      vertical: OmniEspace.m,
                    ),
                  ),
                  style: OmniTypo.corps.copyWith(color: c.texte),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
            ),

            const SizedBox(width: OmniEspace.xs),

            // ── Bouton micro / envoyer ──────────────────────────────
            _BoutonMorph(
              modeEnvoi: _hasText,
              onAppui: _hasText ? _handleSend : widget.onStartRecording,
              onAppuiLong: !_hasText ? widget.onStartRecording : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton qui **morphe** entre « dicter » et « envoyer ».
///
/// Pourquoi une animation ici : un bouton qui change de fonction en
/// silence est un bouton qu'on utilise mal. La rotation et le fondu rendent
/// le changement de rôle perceptible avant l'appui.
class _BoutonMorph extends StatelessWidget {
  const _BoutonMorph({
    required this.modeEnvoi,
    required this.onAppui,
    this.onAppuiLong,
  });

  final bool modeEnvoi;
  final VoidCallback? onAppui;
  final VoidCallback? onAppuiLong;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final actif = onAppui != null;
    const duree = OmniMouvement.rapide;

    return OmniPression(
      borderRadius: OmniRayon.pill,
      onTap: onAppui,
      onLongPress: onAppuiLong,
      actif: actif,
      child: AnimatedContainer(
        duration: duree,
        curve: OmniMouvement.standard,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          // Le dégradé de marque n'apparaît qu'en mode envoi : c'est le
          // signal « cette action va produire quelque chose ».
          gradient: modeEnvoi ? c.degradeAccent : null,
          color: modeEnvoi ? null : c.surfaceVariante,
          shape: BoxShape.circle,
          border: modeEnvoi ? null : Border.all(color: c.contour),
          boxShadow: modeEnvoi
              ? [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: AnimatedSwitcher(
          duration: duree,
          switchInCurve: OmniMouvement.arrivee,
          switchOutCurve: OmniMouvement.depart,
          transitionBuilder: (child, animation) {
            // Rotation + fondu : l'icône pivotante attire l'œil juste ce
            // qu'il faut pour signaler le changement de rôle.
            final rotation = Tween<double>(
              begin: modeEnvoi ? 0.6 : -0.6,
              end: 0,
            ).animate(animation);
            return RotationTransition(
              turns: rotation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Icon(
            modeEnvoi ? Icons.send_rounded : Icons.mic_rounded,
            key: ValueKey<bool>(modeEnvoi),
            color: modeEnvoi ? c.surAccent : c.texte,
            size: 22,
          ),
        ),
      ),
    );
  }
}
