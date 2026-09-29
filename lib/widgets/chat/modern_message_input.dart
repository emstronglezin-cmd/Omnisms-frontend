import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    debugPrint('[DEBUG_SEND] ModernMessageInput _handleSend pressed, hasText=$_hasText, textLen=${text.length}, content=$text');
    if (text.isNotEmpty) {
      debugPrint('[DEBUG_SEND] ModernMessageInput calling onSendMessage');
      widget.onSendMessage(text);
      _controller.clear();
      setState(() {
        _hasText = false;
      });
    } else {
      debugPrint('[DEBUG_SEND] ModernMessageInput empty text, abort');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment button
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
              onPressed: widget.onAttachment,
            ),
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 5,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Send or Voice button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _hasText
                      ? [
                          const Color(0xFF0084FF),
                          const Color(0xFF0066FF),
                        ]
                      : [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.8),
                        ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _hasText ? _handleSend : widget.onStartRecording,
                  onLongPress: !_hasText ? widget.onStartRecording : null,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: Icon(
                      _hasText ? Icons.send_rounded : Icons.mic,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
