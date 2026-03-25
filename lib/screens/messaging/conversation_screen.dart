import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../models/models.dart';

class ConversationScreen extends StatefulWidget {
  final String contactId;
  final String contactName;

  const ConversationScreen({
    super.key,
    required this.contactId,
    required this.contactName,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isSending = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().loadMessages(widget.contactId);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _sendTextMessage() async {
    if (_textController.text.trim().isEmpty) return;

    final text = _textController.text.trim();
    _textController.clear();

    setState(() {
      _isSending = true;
    });

    final success = await context.read<MessagingProvider>().sendTextMessage(
          contactId: widget.contactId,
          content: text,
        );

    setState(() {
      _isSending = false;
    });

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'envoi du message')),
      );
    }

    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _recordingPath = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(),
          path: _recordingPath!,
        );

        setState(() {
          _isRecording = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission microphone requise')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _isSending = true;
      });

      if (path != null) {
        final file = File(path);
        final success = await context.read<MessagingProvider>().sendVoiceMessage(
          contactId: widget.contactId,
          audioFile: file,
        );

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Échec de l\'envoi du message vocal')),
          );
        }
      }

      setState(() {
        _isSending = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _isSending = false;
      });
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showMessageOptions(MessageModel message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.type == MessageType.voice)
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Transcrire'),
                onTap: () async {
                  Navigator.pop(context);
                  _transcribeMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions),
              title: const Text('Réagir'),
              onTap: () {
                Navigator.pop(context);
                _showEmojiPicker(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _confirmDelete();
                if (confirmed) {
                  await context.read<MessagingProvider>().deleteMessage(
                        widget.contactId,
                        message.id,
                      );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _transcribeMessage(MessageModel message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final transcription = await context.read<MessagingProvider>().transcribeMessage(message.id);

    if (mounted) {
      Navigator.pop(context);

      if (transcription != null) {
        context.read<MessagingProvider>().updateMessageTranscription(
              widget.contactId,
              message.id,
              transcription,
            );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transcription: $transcription')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de la transcription')),
        );
      }
    }
  }

  void _showEmojiPicker(MessageModel message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 200,
          child: GridView.count(
            crossAxisCount: 6,
            padding: const EdgeInsets.all(16),
            children: ['❤️', '😂', '😮', '😢', '👍', '👎', '🔥', '🎉', '💯', '✨']
                .map((emoji) => InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        await context.read<MessagingProvider>().reactToMessage(
                              message.id,
                              emoji,
                            );
                      },
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 32)),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Voulez-vous vraiment supprimer ce message ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactName),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // TODO: Implement call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appel vocal (bientôt disponible)')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // TODO: Implement video call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appel vidéo (bientôt disponible)')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Consumer<MessagingProvider>(
              builder: (context, provider, _) {
                final messages = provider.getMessages(widget.contactId);

                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.message_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun message',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Envoyez votre premier message',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message,
                      onLongPress: () => _showMessageOptions(message),
                      onPlayAudio: (url) async {
                        await _audioPlayer.play(UrlSource(url));
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: _isRecording
                ? _buildRecordingBar()
                : _buildInputBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Row(
      children: [
        const Icon(Icons.mic, color: Colors.red),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Enregistrement en cours...'),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelRecording,
        ),
        IconButton(
          icon: const Icon(Icons.send, color: Colors.blue),
          onPressed: _stopRecordingAndSend,
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: 'Message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            maxLines: null,
            textInputAction: TextInputAction.newline,
          ),
        ),
        const SizedBox(width: 8),
        if (_textController.text.trim().isEmpty)
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: _startRecording,
          )
        else
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: _isSending ? null : _sendTextMessage,
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback onLongPress;
  final Function(String) onPlayAudio;

  const _MessageBubble({
    required this.message,
    required this.onLongPress,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: message.isMe
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.type == MessageType.voice)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow, size: 20),
                      onPressed: () {
                        if (message.mediaUrl != null) {
                          onPlayAudio(message.mediaUrl!);
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${message.duration ?? 0}s',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                )
              else
                Text(message.content ?? ''),
              if (message.transcription != null) ...[
                const SizedBox(height: 4),
                Text(
                  message.transcription!,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (message.reaction != null) ...[
                const SizedBox(height: 4),
                Text(
                  message.reaction!,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
