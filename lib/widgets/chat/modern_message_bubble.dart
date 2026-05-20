import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum MessageType { text, audio, image }

class ModernMessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime timestamp;
  final MessageType type;
  final bool isRead;
  final VoidCallback? onLongPress;
  final Widget? audioWidget;
  final String? imageUrl;

  const ModernMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.timestamp,
    this.type = MessageType.text,
    this.isRead = false,
    this.onLongPress,
    this.audioWidget,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) _buildAvatar(context),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFF0084FF)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (type == MessageType.audio && audioWidget != null)
                      audioWidget!
                    else if (type == MessageType.image && imageUrl != null)
                      _buildImage()
                    else
                      _buildTextContent(context),
                    _buildFooter(context),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isMe) _buildSeenStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        message,
        style: TextStyle(
          color: isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 16,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('HH:mm').format(timestamp),
            style: TextStyle(
              color: isMe
                  ? Colors.white.withOpacity(0.7)
                  : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeenStatus() {
    return Icon(
      isRead ? Icons.done_all : Icons.done,
      size: 16,
      color: isRead ? const Color(0xFF0084FF) : Colors.grey,
    );
  }
}
