import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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

  bool _isContactOnline = true;
  DateTime? _lastSeen;

  // Suivi pour le scroll automatique
  // Ne scroll vers le bas qu'après le chargement initial et l'envoi de messages
  bool _hasScrolledToBottom = false;
  int _lastMessageCount = 0;

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
    });

    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _isTyping) {
      setState(() => _isTyping = hasText);
    }
  }

  // ── Send text message ──────────────────────────────────────
  Future<void> _sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() => _isSending = true);

    final success = await context.read<MessagingProvider>().sendTextMessage(
          receiverId: widget.contactId,
          content: text.trim(),
          conversationId: widget.conversationId,
        );

    setState(() => _isSending = false);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Échec de l\'envoi du message'),
          backgroundColor: Colors.red,
        ),
      );
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
            conversationId: widget.conversationId,
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
            content: Text('Erreur: $e'),
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
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              if (message.type == MessageType.voice)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.blue[50], shape: BoxShape.circle),
                    child: const Icon(Icons.text_fields, color: Colors.blue),
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
                      color: Colors.orange[50], shape: BoxShape.circle),
                  child:
                      const Icon(Icons.emoji_emotions, color: Colors.orange),
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
                      color: Colors.red[50], shape: BoxShape.circle),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                title: const Text('Supprimer le message',
                    style: TextStyle(color: Colors.red)),
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

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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
        await context.read<MessagingProvider>().transcribeMessage(message.id);

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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: ConversationHeader(
          imageUrl: widget.contactImageUrl,
          name: widget.contactName,
          isOnline: _isContactOnline,
          lastSeen: _lastSeen,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Profil du contact (bientôt disponible)')),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.black87),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Appel vocal (bientôt disponible)')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.black87),
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Chargement des messages...'),
                      ],
                    ),
                  );
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isGroup
                                ? Icons.group_outlined
                                : Icons.message_outlined,
                            size: 64,
                            color: Colors.blue[300],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Aucun message',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Envoyez votre premier message à ${widget.contactName}',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount:
                      messages.length + (_showTypingIndicator ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_showTypingIndicator && index == messages.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            AvatarWithStatus(
                              imageUrl: widget.contactImageUrl,
                              name: widget.contactName,
                              isOnline: _isContactOnline,
                              size: 32,
                              showStatusIndicator: false,
                            ),
                            const SizedBox(width: 8),
                            const TypingIndicator(),
                          ],
                        ),
                      );
                    }

                    final message = messages[index];

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        modern.ModernMessageBubble(
                          message: message.content ?? '',
                          isMe: message.isMe,
                          timestamp: message.timestamp,
                          type: _getModernMessageType(message.type),
                          isRead:
                              message.status == MessageStatus.read,
                          onLongPress: () =>
                              _showMessageOptions(message),
                          audioWidget:
                              message.type == MessageType.voice
                                  ? AudioPlayerWidget(
                                      audioUrl:
                                          message.mediaUrl ?? '',
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
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Input bar — ALWAYS VISIBLE ─────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
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
