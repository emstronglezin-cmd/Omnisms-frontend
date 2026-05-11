import 'package:flutter/material.dart';

class MessageInputBar extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(String) onSendVoiceMessage;

  const MessageInputBar({
    super.key,
    required this.onSendMessage,
    required this.onSendVoiceMessage,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isRecording = false;
  bool _hasText = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              // TODO: Implement file attachment
            },
          ),
          // Text input
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _hasText = value.trim().isNotEmpty;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // Send button / Mic button
          _hasText
              ? Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        widget.onSendMessage(text);
                        _controller.clear();
                        setState(() {
                          _hasText = false;
                        });
                      }
                    },
                  ),
                )
              : GestureDetector(
                  onLongPress: () {
                    setState(() => _isRecording = true);
                    // TODO: Start voice recording
                  },
                  onLongPressEnd: (_) {
                    setState(() => _isRecording = false);
                    // TODO: Stop voice recording and send
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.mic,
                        color: Colors.white,
                      ),
                      onPressed: null,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
