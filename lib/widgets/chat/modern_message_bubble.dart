import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/avatar_image.dart';
import '../../models/message_model.dart' show MessageStatus;
import '../../theme/omni_design.dart';

/// ⚠️ Widget mobile (APK / IPA). La PWA conserve ses propres composants.

enum MessageType { text, audio, image }

/// Bulle de message — identité OmniSMS.
///
/// Sortante : dégradé cyan → bleu profond, texte sombre, coin bas-droit
/// resserré. Entrante : surface du thème, fine bordure, coin bas-gauche
/// resserré. Rien de ces choix ne reprend le vert de WhatsApp, le bleu clair
/// de Telegram ou le bleu Messenger (#0084FF) utilisé auparavant.
///
/// Le statut affiché provient **toujours** du backend ([status]) : un message
/// en cours d'envoi ou en échec n'arbore jamais la mention « remis ».
class ModernMessageBubble extends StatelessWidget {
  const ModernMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.timestamp,
    this.type = MessageType.text,
    this.isRead = false,
    this.status,
    this.onLongPress,
    this.audioWidget,
    this.imageUrl,
    this.onRetry,
    this.senderName,
    this.afficherAvatar = true,
  });

  final String message;
  final bool isMe;
  final DateTime timestamp;
  final MessageType type;
  final bool isRead;

  /// Statut réellement renvoyé par le backend. Il prime sur [isRead].
  final MessageStatus? status;

  final VoidCallback? onLongPress;

  final Widget? audioWidget;
  final String? imageUrl;

  /// Renvoi d'un message dont l'envoi a échoué.
  final VoidCallback? onRetry;

  /// Nom de l'expéditeur — affiché au-dessus des bulles entrantes dans un
  /// groupe (donnée réelle du backend : `MessageModel.senderName`).
  final String? senderName;

  /// Masque l'avatar quand plusieurs bulles se suivent (séries compactes).
  final bool afficherAvatar;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isMe ? 56 : 12,
          3,
          isMe ? 12 : 56,
          3,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Nom de l'expéditeur (groupes) — donnée réelle, jamais devinée.
            if (!isMe && senderName != null && senderName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 46, bottom: 3),
                child: Text(
                  senderName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniTypo.micro.copyWith(color: c.texteSecondaire),
                ),
              ),
            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe)
                  SizedBox(
                    width: 34,
                    child: afficherAvatar
                        ? UserAvatar(
                            name: senderName ?? 'Contact',
                            size: 34,
                          )
                        : null,
                  ),
                if (!isMe) const SizedBox(width: 8),
                Flexible(child: _bulle(context, c)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulle(BuildContext context, OmniCouleurs c) {
    final contenu = <Widget>[];

    if (type == MessageType.audio && audioWidget != null) {
      contenu.add(audioWidget!);
    } else if (type == MessageType.image && imageUrl != null) {
      contenu.add(_image(context, c));
    } else {
      contenu.add(_texte(c));
    }
    contenu.add(_pied(context, c));

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      decoration: isMe
          ? OmniDecor.bulleSortante(c)
          : OmniDecor.bulleEntrante(c),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: contenu,
      ),
    );
  }

  Widget _texte(OmniCouleurs c) {
    final auVide = type == MessageType.audio || type == MessageType.image;
    if (message.trim().isEmpty && !auVide) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Text(
        message,
        style: OmniTypo.corps.copyWith(
          color: isMe ? c.bulleSortanteTexte : c.bulleEntranteTexte,
          fontSize: 15.5,
          height: 1.38,
        ),
      ),
    );
  }

  Widget _image(BuildContext context, OmniCouleurs c) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(OmniRayon.l),
        bottom: Radius.circular(6),
      ),
      child: SmartImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: Container(
          height: 180,
          color: c.surfaceVariante,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pied de bulle : heure, et statut serveur aligné à droite pour mes
  /// messages (les coches sont désormais DANS la bulle).
  Widget _pied(BuildContext context, OmniCouleurs c) {
    final couleurHeure = isMe
        ? c.bulleSortanteTexte.withValues(alpha: 0.62)
        : c.texteEstompe;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 12, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('HH:mm').format(timestamp),
            style: OmniTypo.micro.copyWith(color: couleurHeure, fontSize: 10.5),
          ),
          if (isMe) ...[
            const SizedBox(width: 5),
            _statut(c),
          ],
        ],
      ),
    );
  }

  /// Indicateur d'état, strictement calé sur le statut serveur :
  ///   envoi en cours → horloge ; échec → point d'exclamation (rouge) ;
  ///   remis → double coche ; lu → double coche en couleur d'accent.
  ///
  /// Aucun message n'est présenté comme remis sans confirmation du serveur.
  Widget _statut(OmniCouleurs c) {
    final etat = status;

    if (etat != null) {
      switch (etat) {
        case MessageStatus.sending:
          return Icon(Icons.schedule_rounded,
              size: 14, color: c.bulleSortanteTexte.withValues(alpha: 0.7));
        case MessageStatus.failed:
          return GestureDetector(
            onTap: onRetry,
            child: const Icon(Icons.error_outline_rounded,
                size: 15, color: OmniPalette.erreur),
          );
        case MessageStatus.read:
          return Icon(Icons.done_all_rounded, size: 15, color: c.surAccent);
        case MessageStatus.delivered:
          return Icon(Icons.done_all_rounded,
              size: 15, color: c.bulleSortanteTexte.withValues(alpha: 0.75));
        case MessageStatus.sent:
          return Icon(Icons.done_rounded,
              size: 15, color: c.bulleSortanteTexte.withValues(alpha: 0.6));
      }
    }

    // Repli (statut absent) : comportement historique.
    return Icon(
      isRead ? Icons.done_all_rounded : Icons.done_rounded,
      size: 15,
      color: isRead
          ? c.surAccent
          : c.bulleSortanteTexte.withValues(alpha: 0.6),
    );
  }
}
