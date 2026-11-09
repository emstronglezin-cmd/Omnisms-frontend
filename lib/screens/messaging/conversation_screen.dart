import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import '../../theme/omni_design.dart';
import '../../theme/omni_motion.dart';
import '../../utils/user_messages.dart';
import 'package:provider/provider.dart';
import '../../providers/messaging_provider.dart';
import '../../models/models.dart';
import '../../widgets/chat/modern_message_bubble.dart' as modern;
import '../../widgets/chat/modern_message_input.dart';
import '../../widgets/chat/typing_indicator.dart';
import '../../widgets/chat/online_status_widget.dart';
import '../../widgets/chat/reaction_widget.dart';
import '../../widgets/audio/voice_recorder_widget.dart';
import '../../widgets/audio/audio_player_widget.dart';
import '../../services/presence_service.dart';
import '../../services/realtime_service.dart';

/// ConversationScreen — Full message thread.
///
/// Parameters:
///   conversationId  → used to load history (GET /api/messages/:conversationId)
///   contactId       → receiverId for sending messages
///   contactName     → displayed in app bar
///   contactImageUrl → optional avatar
///   isGroup         → true for group conversations
///
/// The input bar is ALWAYS visible (even with zero messages).
class ConversationScreen extends StatefulWidget {
  /// The conversation ID (used for GET /api/messages/:conversationId)
  final String conversationId;

  /// The other user's ID (used for POST /api/messages/send as receiverId)
  final String contactId;

  final String contactName;
  final String? contactImageUrl;
  final bool isGroup;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    required this.contactId,
    required this.contactName,
    this.contactImageUrl,
    this.isGroup = false,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isRecording = false;
  bool _isSending = false;
  bool _isTyping = false;
  bool _showTypingIndicator = false;

  // Présence du destinataire : trois états possibles (connecté, déconnecté,
  // inconnu). Elle vient du backend (session Socket.IO), jamais de la
  // connectivité du téléphone — et surtout jamais d'une valeur codée en dur.
  PresenceInfo _presence = const PresenceInfo.unknown('');

  // Suivi pour le scroll automatique
  // Ne scroll vers le bas qu'après le chargement initial et l'envoi de messages
  bool _hasScrolledToBottom = false;
  int _lastMessageCount = 0;

  // ─── V3 ────────────────────────────────────────────────────────────────
  /// Vrai quand l'utilisateur a remonté dans l'historique : on affiche alors
  /// un bouton de retour au bas. Sans ce repère, un nouvel message reçu
  /// alors qu'on lit d'anciens messages laisse l'utilisateur perdu.
  final ValueNotifier<bool> _loinDuBas = ValueNotifier<bool>(false);

  /// Vrai pendant l'image qui suit l'arrivée d'un nouveau message : la
  /// dernière bulle est alors animée. Consommé par l'`itemBuilder`, puis
  /// remis à faux — l'animation ne se rejoue pas à chaque reconstruction.
  bool _animerDernierMessage = false;

  /// Service de présence capturé : `context` n'est plus utilisable dans
  /// `dispose()`. (Le champ `_presence`, lui, est l'état courant.)
  PresenceService? _servicePresence;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _servicePresence ??= context.read<PresenceService>();
  }

  @override
  void initState() {
    super.initState();
    // Tell provider which conversation is active (for focused polling)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<MessagingProvider>();
      provider.setActiveConversation(widget.conversationId);
      // Load history using conversationId
      provider.loadMessages(widget.conversationId);

      // Présence réelle du destinataire (backend). Pour un groupe, la notion
      // de présence individuelle n'a pas de sens : on ne suit rien.
      if (!widget.isGroup && widget.contactId.isNotEmpty) {
        context.read<PresenceService>().watch(widget.contactId);
      }
    });

    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_surveillerDefilement);
  }

  /// Met à jour l'indicateur « éloigné du bas ».
  ///
  /// Le seuil de 300 dp est volontairement large : proche du bas, le défilement
  /// automatique reste pertinent et le bouton n'a aucune raison d'apparaître.
  void _surveillerDefilement() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distance = position.maxScrollExtent - position.pixels;
    final loin = distance > 300;
    if (_loinDuBas.value != loin) _loinDuBas.value = loin;
  }

  @override
  void dispose() {
    // Effacer la conversation active pour que les notifications reprennent
    // après avoir quitté cet écran.
    // Bug Session 11 : sans ce clearance, _activeConversationId reste défini
    // et TOUTES les notifications suivantes pour cette conversation sont
    // silencieusement ignorées même lorsque l'utilisateur n'est plus dans la conv.
    //
    // La référence a été capturée dans `didChangeDependencies` : utiliser
    // `context.read` ici échoue parfois (arbre en cours de démontage) et
    // l'échec était avalé par le `catch`, laissant le suivi de présence — et
    // son minuteur — tourner après la fermeture de la conversation.
    try {
      if (!widget.isGroup && widget.contactId.isNotEmpty) {
        _servicePresence?.unwatch(widget.contactId);
      }
    } catch (_) {}
    try {
      final provider = context.read<MessagingProvider>();
      provider.setActiveConversation(null);
      debugPrint('[NOTIFICATION] ConversationScreen dispose — activeConv cleared');
    } catch (_) {}
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _loinDuBas.dispose();
    super.dispose();
  }

  // ─── V3 · Construction de la liste (séparateurs de jour) ─────────────────

  /// Découpe la liste de messages en entrées affichables, en insérant un
  /// séparateur chaque fois que le jour change.
  ///
  /// Pourquoi c'est important : dans une conversation qui dure, l'absence de
  /// repère temporel oblige à remonter message par message pour savoir
  /// « quand » quelque chose a été dit. Un séparateur par jour est le
  /// moyen le plus sobre de rendre l'historique lisible — c'est aussi ce que
  /// font les messageries de référence.
  List<_EntreeListe> _construireEntrees(List<MessageModel> messages) {
    final entrees = <_EntreeListe>[];
    DateTime? jourCourant;

    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final jour = _jourDe(message.timestamp);

      if (jourCourant == null || !_estMemeJour(jourCourant, jour)) {
        entrees.add(_EntreeListe.separateur(jour));
        jourCourant = jour;
      }

      // Séries compactes : l'avatar n'est affiché que sur la dernière bulle
      // d'un même expéditeur. Un séparateur interrompt la série, sinon un
      // avatar manquerait juste avant « Hier ».
      final suivant = i + 1 < messages.length ? messages[i + 1] : null;
      final jourSuivant = suivant == null ? null : _jourDe(suivant.timestamp);
      final serieInterrompue = suivant == null ||
          suivant.isMe != message.isMe ||
          (jourSuivant != null && !_estMemeJour(jour, jourSuivant));

      entrees.add(_EntreeListe.message(i, afficherAvatar: serieInterrompue));
    }

    return entrees;
  }

  static DateTime _jourDe(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _estMemeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _isTyping) {
      setState(() => _isTyping = hasText);
    }
  }

  // ── Send text message ──────────────────────────────────────
  Future<void> _sendTextMessage(String text) async {
    debugPrint('[DEBUG_SEND] ConversationScreen _sendTextMessage called, textLen=${text.length}, content=$text');
    debugPrint('[DEBUG_SEND] receiverId(contactId)=${widget.contactId}, conversationId=${widget.conversationId}, isGroup=${widget.isGroup}');
    if (text.trim().isEmpty) {
      debugPrint('[DEBUG_SEND] ConversationScreen empty text, abort');
      return;
    }

    setState(() => _isSending = true);

    try {
      debugPrint('[DEBUG_SEND] ConversationScreen calling MessagingProvider.sendTextMessage');
      final success = await context.read<MessagingProvider>().sendTextMessage(
            receiverId: widget.contactId,
            content: text.trim(),
            conversationId: widget.conversationId,
          );
      debugPrint('[DEBUG_SEND] ConversationScreen provider returned success=$success');
      setState(() => _isSending = false);

      // Le canal réellement utilisé est annoncé, jamais supposé.
      final provider = context.read<MessagingProvider>();
      if (success && provider.lastSendSmsFallback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Destinataire hors ligne à cet instant : message envoyé par SMS.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }

      if (!success && mounted) {
        debugPrint('[DEBUG_SEND] ConversationScreen send failed → snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Échec de l\'envoi du message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[DEBUG_SEND] ConversationScreen exception: $e\n$st');
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage(
              e,
              fallback: 'Envoi impossible. Vérifiez votre connexion.',
            )),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Forcer le scroll vers le bas après envoi
    _scrollToBottom();
  }

  // ── Voice message ──────────────────────────────────────────
  void _onRecordingComplete(String audioPath, Duration duration) async {
    setState(() {
      _isRecording = false;
      _isSending = true;
    });

    try {
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Messages vocaux non supportés sur le web'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isSending = false);
        return;
      }

      final success = await context.read<MessagingProvider>().sendVoiceMessage(
            contactId: widget.contactId,
            audioFile: audioPath,
            duration: duration.inSeconds,
            conversationId: widget.conversationId,
            isGroup: widget.isGroup,
          );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Échec de l\'envoi du message vocal'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage(
              e,
              fallback: 'Envoi du message vocal impossible.',
            )),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _onRecordingCancel() => setState(() => _isRecording = false);
  void _startRecording() => setState(() => _isRecording = true);

  /// Scroll vers le bas de la conversation.
  /// N'est appelé que lors du chargement initial et de l'envoi/réception de messages.
  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;
      if (animate) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  // ── Message options sheet ──────────────────────────────────
  void _showMessageOptions(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final c = OmniCouleurs.of(context);
        return Container(
        decoration: BoxDecoration(
          color: c.fondSecondaire,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.texteEstompe.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              if (message.type == MessageType.voice)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: c.accentDoux, shape: BoxShape.circle),
                    child: Icon(Icons.text_fields_rounded,
                        size: 20, color: c.accent),
                  ),
                  title: const Text('Transcrire le message vocal'),
                  subtitle: const Text('Convertir en texte'),
                  onTap: () async {
                    Navigator.pop(context);
                    _transcribeMessage(message);
                  },
                ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: OmniPalette.avertissement.withValues(alpha: 0.14),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.emoji_emotions_rounded,
                      size: 20, color: OmniPalette.avertissement),
                ),
                title: const Text('Réagir au message'),
                subtitle: const Text('Ajouter un emoji'),
                onTap: () {
                  Navigator.pop(context);
                  _showEmojiReactionPicker(message);
                },
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: OmniPalette.erreur.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: OmniPalette.erreur),
                ),
                title: const Text('Supprimer le message',
                    style: TextStyle(color: OmniPalette.erreur)),
                subtitle: const Text('Cette action est irréversible'),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await _confirmDelete();
                  if (confirmed) {
                    await context.read<MessagingProvider>().deleteMessage(
                          widget.conversationId,
                          message.id,
                        );
                  }
                },
              ),

              const SizedBox(height: OmniEspace.l),
            ],
          ),
        ),
        );
      },
    );
  }

  Future<void> _transcribeMessage(MessageModel message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Transcription en cours...'),
              ],
            ),
          ),
        ),
      ),
    );

    final transcription =
        await context.read<MessagingProvider>().transcribeMessage(
              message.id,
              conversationId: widget.conversationId,
            );

    if (mounted) {
      Navigator.pop(context);
      if (transcription != null && transcription.isNotEmpty) {
        context.read<MessagingProvider>().updateMessageTranscription(
              widget.conversationId,
              message.id,
              transcription,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transcription terminée: ${transcription.substring(0, transcription.length > 30 ? 30 : transcription.length)}...',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Échec de la transcription'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEmojiReactionPicker(MessageModel message) {
    showEmojiReactionPicker(
      context: context,
      isMe: message.isMe,
      onEmojiSelected: (emoji) async {
        await context
            .read<MessagingProvider>()
            .reactToMessage(message.id, emoji);
      },
    );
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Supprimer le message'),
          ],
        ),
        content: const Text(
          'Voulez-vous vraiment supprimer ce message ?\n\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Présence réelle, issue du backend (3 états distincts).
    final presence = widget.isGroup
        ? const PresenceInfo.unknown('')
        : context.watch<PresenceService>().stateOf(widget.contactId);
    _presence = presence;
    final isContactOnline = presence.isOnline;

    final c = OmniCouleurs.of(context);

    return Scaffold(
      // Avant : `Colors.grey[50]` imposé, donc écran clair y compris en thème
      // sombre. Le fond suit désormais le thème.
      backgroundColor: c.fond,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.fondSecondaire,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: c.texte),
          onPressed: () => Navigator.pop(context),
        ),
        title: ConversationHeader(
          imageUrl: widget.contactImageUrl,
          name: widget.contactName,
          isOnline: isContactOnline,
          lastSeen: presence.lastSeen,
          presence: presence,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Profil du contact (bientôt disponible)')),
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call_rounded, color: c.texte),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Appel vocal (bientôt disponible)')),
            ),
          ),
          IconButton(
            icon: Icon(Icons.videocam_rounded, color: c.texte),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Appel vidéo (bientôt disponible)')),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // Body: messages list + FIXED input bar at bottom
      body: Column(
        children: [
          // ── Messages area ─────────────────────────────────
          Expanded(
            child: Consumer<MessagingProvider>(
              builder: (context, provider, _) {
                final messages =
                    provider.getMessages(widget.conversationId);
                final isLoading =
                    provider.isLoadingMessages(widget.conversationId);

                if (isLoading && messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: c.accent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          OmniEtats.chargement,
                          style: OmniTypo.secondaire.copyWith(
                            color: c.texteSecondaire,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (messages.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(OmniEspace.xxxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              color: c.accentDoux,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isGroup
                                  ? Icons.groups_rounded
                                  : Icons.forum_rounded,
                              size: 42,
                              color: c.accent,
                            ),
                          ),
                          const SizedBox(height: OmniEspace.xl),
                          Text(
                            'Aucun message',
                            style: OmniTypo.sousTitre.copyWith(color: c.texte),
                          ),
                          const SizedBox(height: OmniEspace.s),
                          Text(
                            'Envoyez votre premier message à ${widget.contactName}',
                            style: OmniTypo.secondaire.copyWith(
                              color: c.texteSecondaire,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Scroll automatique UNIQUEMENT :
                // 1. Premier chargement de l'historique
                // 2. Nouveau message reçu/envoyé (count augmenté)
                // NE PAS scroller à chaque rebuild (évite de bloquer
                // l'utilisateur qui remonte dans l'historique)
                if (!_hasScrolledToBottom) {
                  _hasScrolledToBottom = true;
                  _lastMessageCount = messages.length;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToBottom(animate: false),
                  );
                } else if (messages.length > _lastMessageCount) {
                  // Nouveau(x) message(s) → scroller seulement si
                  // l'utilisateur est déjà en bas (ou proche du bas)
                  _lastMessageCount = messages.length;
                  final atBottom = !_scrollController.hasClients ||
                      _scrollController.position.pixels >=
                          _scrollController.position.maxScrollExtent - 150;
                  if (atBottom) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom(),
                    );
                  }
                  // V3 — le dernier message s'animera à la prochaine image.
                  _animerDernierMessage = true;
                }

                // V3 — la liste est découpée en entrées : un séparateur est
                // inséré à chaque changement de jour.
                final entrees = _construireEntrees(messages);

                return Stack(
                  children: [
                    ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount:
                      entrees.length + (_showTypingIndicator ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_showTypingIndicator && index == entrees.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            AvatarWithStatus(
                              imageUrl: widget.contactImageUrl,
                              name: widget.contactName,
                              isOnline: isContactOnline,
                              size: 32,
                              showStatusIndicator: false,
                            ),
                            const SizedBox(width: 8),
                            const TypingIndicator(),
                          ],
                        ),
                      );
                    }

                    final entree = entrees[index];

                    // Séparateur de jour : repère temporel discret.
                    if (entree.estSeparateur) {
                      return _SeparateurJour(date: entree.jour!);
                    }

                    final message = messages[entree.indexMessage!];
                    final canRetry =
                        message.isMe && provider.canRetry(message.id);

                    // L'avatar est décidé lors de la construction des
                    // entrées : une série s'interrompt au changement
                    // d'expéditeur **et** au changement de jour.
                    final afficherAvatar = entree.afficherAvatar;

                    // V3 — la dernière bulle s'anime à l'arrivée d'un
                    // nouveau message. Le drapeau est consommé ici puis
                    // remis à faux : l'animation ne se rejoue pas à chaque
                    // reconstruction de la liste.
                    final animer = _animerDernierMessage &&
                        entree.indexMessage == messages.length - 1;
                    if (animer) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _animerDernierMessage = false;
                      });
                    }

                    Widget bulle = Stack(
                      clipBehavior: Clip.none,
                      children: [
                        modern.ModernMessageBubble(
                          message: message.content ?? '',
                          isMe: message.isMe,
                          timestamp: message.timestamp,
                          type: _getModernMessageType(message.type),
                          isRead:
                              message.status == MessageStatus.read,
                          // Statut serveur : jamais « remis » sans confirmation.
                          status: message.status,
                          onRetry: canRetry
                              ? () => context
                                  .read<MessagingProvider>()
                                  .retryMessage(message.id)
                              : null,
                          onLongPress: () =>
                              _showMessageOptions(message),
                          // Nom de l'expéditeur : données réelles du backend
                          // (`senderName`), affiché dans les groupes.
                          senderName: widget.isGroup ? message.senderName : null,
                          afficherAvatar: afficherAvatar,
                          audioWidget:
                              message.type == MessageType.voice
                                  ? AudioPlayerWidget(
                                      audioUrl:
                                          message.playableAudioUrl,
                                      duration: Duration(
                                          seconds:
                                              message.duration ?? 0),
                                      transcription:
                                          message.transcription,
                                      isMe: message.isMe,
                                    )
                                  : null,
                          imageUrl: message.type == MessageType.image
                              ? message.mediaUrl
                              : null,
                        ),

                        if (message.reaction != null &&
                            message.reaction!.isNotEmpty)
                          ReactionWidget(
                            emoji: message.reaction!,
                            isMe: message.isMe,
                          ),

                        // Message interne vs SMS : distinction explicite.
                        if (message.isSms)
                          Positioned(
                            left: message.isMe ? null : 8,
                            right: message.isMe ? 8 : null,
                            bottom: -2,
                            child: _ChannelChip(
                              label: 'SMS',
                              color: Colors.orange.shade700,
                              icon: Icons.sms_outlined,
                            ),
                          ),

                        // Envoi resté en échec : bouton de renvoi explicite.
                        if (canRetry)
                          Positioned(
                            right: message.isMe ? null : 8,
                            left: message.isMe ? 8 : null,
                            bottom: -4,
                            child: _RetryButton(
                              onPressed: () async {
                                final ok = await context
                                    .read<MessagingProvider>()
                                    .retryMessage(message.id);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? 'Message renvoyé.'
                                        : "Échec du renvoi. Réessayez."),
                                    backgroundColor:
                                        ok ? Colors.green : Colors.red,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );

                    if (!animer) return bulle;
                    return OmniApparition(
                      duree: OmniMouvement.moyen,
                      distance: 10,
                      child: bulle,
                    );
                  },
                ),

                    // V3 — retour au bas. Apparaît uniquement quand
                    // l'utilisateur a remonté l'historique : sans ce repère,
                    // un message reçu pendant la lecture d'anciens échanges
                    // passerait inaperçu et la position serait perdue.
                    ValueListenableBuilder<bool>(
                      valueListenable: _loinDuBas,
                      builder: (context, visible, _) {
                        return AnimatedPositioned(
                          duration: OmniMouvement.moyen,
                          curve: OmniMouvement.arrivee,
                          right: 16,
                          bottom: visible ? 16 : -72,
                          child: AnimatedOpacity(
                            duration: OmniMouvement.court,
                            opacity: visible ? 1 : 0,
                            child: _BoutonRetourBas(
                              nonLus: 0,
                              onPressed: () => _scrollToBottom(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Acheminement annoncé (jamais deviné) ───────────
          // Le backend décide au moment de l'envoi ; on affiche ici l'état de
          // présence qui expliquera cette décision.
          if (!widget.isGroup) _RoutingHint(presence: _presence),

          // ── Input bar — ALWAYS VISIBLE ─────────────────────
          Container(
            decoration: BoxDecoration(
              color: c.fondSecondaire,
              border: Border(top: BorderSide(color: c.contour)),
            ),
            child: SafeArea(
              child: _isRecording
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: VoiceRecorderWidget(
                        onRecordingComplete: _onRecordingComplete,
                        onCancel: _onRecordingCancel,
                      ),
                    )
                  : ModernMessageInput(
                      onSendMessage: _sendTextMessage,
                      onStartRecording: _startRecording,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  modern.MessageType _getModernMessageType(MessageType type) {
    switch (type) {
      case MessageType.voice:
        return modern.MessageType.audio;
      case MessageType.image:
        return modern.MessageType.image;
      default:
        return modern.MessageType.text;
    }
  }
}

/// Bandeau expliquant l'acheminement probable, à partir de la présence RÉELLE.
///
/// Aucune promesse : le backend décide au moment de l'envoi. On indique
/// seulement ce que la présence connue laisse prévoir.
class _RoutingHint extends StatelessWidget {
  final PresenceInfo presence;

  const _RoutingHint({required this.presence});

  @override
  Widget build(BuildContext context) {
    final (String text, Color color, IconData icon) = switch (presence.state) {
      PresenceState.online => (
          'Destinataire connecté : message OmniSMS (sans frais SMS).',
          Colors.green.shade700,
          Icons.flash_on_rounded,
        ),
      PresenceState.offline => (
          'Destinataire hors ligne : le serveur enverra un SMS.',
          Colors.orange.shade700,
          Icons.sms_outlined,
        ),
      PresenceState.unknown => (
          'Présence inconnue : le serveur choisira OmniSMS ou SMS à l\'envoi.',
          Colors.grey.shade700,
          Icons.help_outline_rounded,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: color.withOpacity(0.08),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Étiquette « SMS » sous un message réellement passé par le réseau SMS.
class _ChannelChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _ChannelChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton « Renvoyer » sur un message resté en échec.
class _RetryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RetryButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade50,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.refresh_rounded,
              size: 16, color: Colors.red.shade700),
        ),
      ),
    );
  }
}


// ─── V3 · Entrées de liste, séparateurs de jour, retour au bas ──────────────

/// Une entrée affichable de la liste de messages.
///
/// Soit un séparateur de jour, soit un message (avec la décision
/// d'affichage de l'avatar, calculée une seule fois).
class _EntreeListe {
  const _EntreeListe.separateur(this.jour)
      : indexMessage = null,
        afficherAvatar = false;

  const _EntreeListe.message(this.indexMessage, {required this.afficherAvatar})
      : jour = null;

  final DateTime? jour;
  final int? indexMessage;
  final bool afficherAvatar;

  bool get estSeparateur => jour != null;
}

/// Repère de jour (« Aujourd'hui », « Hier », ou la date).
///
/// Volontairement discret : c'est une information de contexte, pas un titre.
/// Elle ne doit pas concurrencer les bulles.
class _SeparateurJour extends StatelessWidget {
  const _SeparateurJour({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);
    final maintenant = DateTime.now();
    final aujourdhui =
        DateTime(maintenant.year, maintenant.month, maintenant.day);
    final hier = aujourdhui.subtract(const Duration(days: 1));
    final jour = DateTime(date.year, date.month, date.day);

    final String libelle;
    if (jour == aujourdhui) {
      libelle = "Aujourd'hui";
    } else if (jour == hier) {
      libelle = 'Hier';
    } else if (maintenant.difference(jour).inDays < 7) {
      // À moins d'une semaine, le nom du jour est plus parlant que la date.
      const noms = [
        'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
      ];
      libelle = noms[date.weekday - 1];
    } else {
      final j = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      libelle = '$j/$m/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniEspace.xxxl,
        vertical: OmniEspace.m,
      ),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.contour, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: OmniEspace.m),
            child: Text(
              libelle,
              style: OmniTypo.etiquette.copyWith(color: c.texteEstompe),
            ),
          ),
          Expanded(child: Divider(color: c.contour, thickness: 1)),
        ],
      ),
    );
  }
}

/// Bouton flottant « retour au bas ».
///
/// N'apparaît que lorsque l'utilisateur a remonté l'historique. Le compteur
/// de nouveaux messages reste à 0 tant que le fournisseur n'expose pas le
/// nombre de messages arrivés hors écran : plutôt que d'afficher un chiffre
/// inventé, le bouton n'en montre aucun.
class _BoutonRetourBas extends StatelessWidget {
  const _BoutonRetourBas({required this.nonLus, required this.onPressed});

  final int nonLus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);

    return Semantics(
      button: true,
      label: 'Revenir aux messages les plus récents',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: c.degradeAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.accent.withValues(alpha: 0.34),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
