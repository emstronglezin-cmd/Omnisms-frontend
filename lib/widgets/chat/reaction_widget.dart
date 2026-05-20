import 'package:flutter/material.dart';

/// Widget pour afficher les réactions emoji sur les messages
class ReactionWidget extends StatelessWidget {
  final String emoji;
  final bool isMe;

  const ReactionWidget({
    super.key,
    required this.emoji,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: -8,
      right: isMe ? 12 : null,
      left: isMe ? null : 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

/// Sélecteur de réactions emoji moderne style Instagram
class EmojiReactionPicker extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;
  final bool isMe;

  const EmojiReactionPicker({
    super.key,
    required this.onEmojiSelected,
    this.isMe = false,
  });

  static const List<String> _defaultEmojis = [
    '❤️', '😂', '😮', '😢', '😍', '🔥',
    '👍', '👎', '🎉', '💯', '✨', '🙏',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _defaultEmojis.map((emoji) {
          return GestureDetector(
            onTap: () => onEmojiSelected(emoji),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bottom sheet moderne pour sélectionner une réaction
void showEmojiReactionPicker({
  required BuildContext context,
  required Function(String emoji) onEmojiSelected,
  bool isMe = false,
}) {
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
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Réagir au message',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Emoji grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: EmojiReactionPicker(
                onEmojiSelected: (emoji) {
                  Navigator.pop(context);
                  onEmojiSelected(emoji);
                },
                isMe: isMe,
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
