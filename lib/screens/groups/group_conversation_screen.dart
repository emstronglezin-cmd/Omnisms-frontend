import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/groups_service.dart';

class GroupConversationScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupConversationScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupConversationScreen> createState() => _GroupConversationScreenState();
}

class _GroupConversationScreenState extends State<GroupConversationScreen> {
  final GroupsService _groupsService = GroupsService();
  final AuthService _authService = AuthService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<MessageModel> _messages = [];
  final Map<String, String> _memberNames = {};
  Timer? _pollTimer;
  String? _currentUserId;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    _currentUserId = await _authService.getUserId();
    await _loadMembers();
    await _loadMessages(showLoader: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadMessages();
    });
  }

  Future<void> _loadMembers() async {
    final members = await _groupsService.getGroupMembers(widget.groupId);
    if (!mounted) return;
    setState(() {
      for (final m in members) {
        final uid = m['uid']?.toString();
        final name = m['name']?.toString();
        if (uid != null && name != null && name.isNotEmpty) {
          _memberNames[uid] = name;
        }
      }
    });
  }

  Future<void> _loadMessages({bool showLoader = false}) async {
    try {
      final messages =
          await _groupsService.getGroupMessages(widget.groupId);
      if (!mounted) return;

      setState(() {
        _error = null;
        _isLoading = false;
        final existingIds = _messages.map((m) => m.id).toSet();
        _messages.addAll(
          messages.where((m) => !existingIds.contains(m.id)),
        );
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      if (showLoader) {
        setState(() {
          _isLoading = false;
          _error = 'Impossible de charger les messages';
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _isSending) return;

    _textController.clear();
    final currentUserId = _currentUserId ?? '';

    final optimistic = MessageModel(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.groupId,
      senderId: currentUserId,
      type: MessageType.text,
      content: content,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      isMe: true,
    );

    setState(() {
      _isSending = true;
      _messages.add(optimistic);
    });
    _scrollToBottom();

    final sent = await _groupsService.sendGroupMessage(
      groupId: widget.groupId,
      content: content,
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
      final idx = _messages.indexWhere((m) => m.id == optimistic.id);
      if (sent != null) {
        final confirmed = sent.copyWith(
          isMe: sent.senderId == currentUserId || sent.senderId.isEmpty,
          senderId: sent.senderId.isEmpty ? currentUserId : sent.senderId,
          conversationId:
              sent.conversationId.isEmpty ? widget.groupId : sent.conversationId,
        );
        if (idx >= 0) {
          _messages[idx] = confirmed;
        } else {
          _messages.add(confirmed);
        }
      } else if (idx >= 0) {
        _messages[idx] = optimistic.copyWith(status: MessageStatus.failed);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Échec de l'envoi du message"),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName),
            Text(
              '${_memberNames.length} membres',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appel de groupe (bientôt disponible)')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showGroupInfo(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadMessages(showLoader: true);
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Messages de groupe',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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

    return RefreshIndicator(
      onRefresh: () => _loadMessages(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isMe = message.isMe ||
              message.senderId == _currentUserId;
          final senderName =
              _memberNames[message.senderId] ?? message.senderName;
          return _buildBubble(message, isMe, senderName);
        },
      ),
    );
  }

  Widget _buildBubble(MessageModel message, bool isMe, String? senderName) {
    final alignment =
        isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isMe
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceVariant;
    final textColor = isMe
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe && senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          Align(
            alignment: alignment,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Text(
                message.content ?? '',
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 12, right: 12),
            child: Text(
              _formatTime(message.timestamp),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime ts) {
    return '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
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
              controller: _textController,
              onSubmitted: (_) => _sendMessage(),
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
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final entries = _memberNames.entries.toList();
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.groupName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${entries.length} membres',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const Divider(height: 24),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Chargement des membres...'),
                )
              else
                ...entries.map(
                  (e) => ListTile(
                    leading: CircleAvatar(
                      child: Text(e.value.isNotEmpty
                          ? e.value[0].toUpperCase()
                          : '?'),
                    ),
                    title: Text(e.value),
                    dense: true,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
