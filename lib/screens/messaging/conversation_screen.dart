import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/messaging_service.dart';
import '../../services/audio_recording_service.dart';
import '../../models/models.dart';

class ConversationScreen extends StatefulWidget {
  final String? contactName;
  final String? contactId;

  const ConversationScreen({
    super.key,
    this.contactName,
    this.contactId,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final MessagingService _messagingService = MessagingService();
  final AudioRecordingService _audioService = AudioRecordingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isRecording = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagingService.disconnectWebSocket();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (widget.contactId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final messages = await _messagingService.getMessages(
        contactId: widget.contactId!,
      );
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _connectWebSocket() {
    _messagingService.connectWebSocket((message) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.contactId == null) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      final message = await _messagingService.sendTextMessage(
        receiverId: widget.contactId!,
        content: text,
      );

      if (message != null) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioService.requestPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission microphone requise')),
      );
      return;
    }

    final started = await _audioService.startRecording();
    if (started) {
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _stopRecording() async {
    final audioFile = await _audioService.stopRecording();
    setState(() {
      _isRecording = false;
    });

    if (audioFile != null && widget.contactId != null) {
      try {
        final message = await _messagingService.sendVoiceMessage(
          receiverId: widget.contactId!,
          audioFile: audioFile,
        );

        if (message != null) {
          setState(() {
            _messages.add(message);
          });
          _scrollToBottom();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur envoi vocal: $e')),
        );
      }
    }
  }

  void _showMessageOptions(MessageModel message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.type == MessageType.voice)
            ListTile(
              leading: const Icon(Icons.transcribe),
              title: const Text('Transcrire'),
              onTap: () {
                Navigator.pop(context);
                _transcribeMessage(message);
              },
            ),
          ListTile(
            leading: const Icon(Icons.emoji_emotions),
            title: const Text('Réagir'),
            onTap: () {
              Navigator.pop(context);
              _reactToMessage(message);
            },
          ),
          if (message.isMe)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _transcribeMessage(MessageModel message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final transcription = await _messagingService.transcribeVoiceMessage(
        message.id,
      );

      Navigator.pop(context);

      if (transcription != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Transcription'),
            content: Text(transcription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur transcription: $e')),
      );
    }
  }

  Future<void> _reactToMessage(MessageModel message) async {
    // Show emoji picker (simplified)
    final emoji = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une réaction'),
        content: Wrap(
          spacing: 16,
          children: ['❤️', '👍', '😂', '😮', '😢', '😡']
              .map((e) => InkWell(
                    onTap: () => Navigator.pop(context, e),
                    child: Text(e, style: const TextStyle(fontSize: 32)),
                  ))
              .toList(),
        ),
      ),
    );

    if (emoji != null) {
      await _messagingService.reactToMessage(message.id, emoji);
    }
  }

  Future<void> _deleteMessage(MessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Êtes-vous sûr ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _messagingService.deleteMessage(message.id);
      if (success) {
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactName ?? 'Conversation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appel vocal')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appel vidéo')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun message',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return GestureDetector(
                            onLongPress: () => _showMessageOptions(message),
                            child: _buildMessageBubble(message),
                          );
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: message.isMe
              ? Theme.of(context).colorScheme.primary
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
                  Icon(
                    Icons.play_arrow,
                    color: message.isMe ? Colors.white : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${message.duration ?? 0}s',
                    style: TextStyle(
                      color: message.isMe ? Colors.white : null,
                    ),
                  ),
                ],
              )
            else
              Text(
                message.content ?? '',
                style: TextStyle(
                  color: message.isMe ? Colors.white : null,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: message.isMe
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
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
            ),
          ),
          const SizedBox(width: 8),
          if (_isRecording)
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: _stopRecording,
            )
          else
            IconButton(
              icon: Icon(
                _messageController.text.isEmpty ? Icons.mic : Icons.send,
              ),
              onPressed: _messageController.text.isEmpty
                  ? _startRecording
                  : _sendMessage,
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
