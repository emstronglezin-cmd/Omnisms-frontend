import 'package:flutter/material.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input_bar.dart';

class ConversationScreen extends StatefulWidget {
  final String? contactName;
  const ConversationScreen({super.key, this.contactName});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final List<Map<String, dynamic>> messages = [
    {
      'text': 'Salut! Comment ça va?',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      'isVoice': false,
    },
    {
      'text': 'Ça va bien, et toi?',
      'isMe': true,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 4)),
      'isVoice': false,
    },
    {
      'text': 'Tout va bien! On se voit bientôt?',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 3)),
      'isVoice': false,
    },
  ];

  void _handleSendMessage(String message) {
    setState(() {
      messages.add({
        'text': message,
        'isMe': true,
        'timestamp': DateTime.now(),
        'isVoice': false,
      });
    });
  }

  void _handleSendVoiceMessage(String path) {
    setState(() {
      messages.add({
        'text': path,
        'isMe': true,
        'timestamp': DateTime.now(),
        'isVoice': true,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactName ?? 'Conversation'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return MessageBubble(
                  text: message['text'],
                  isMe: message['isMe'],
                  timestamp: message['timestamp'],
                  isVoice: message['isVoice'],
                );
              },
            ),
          ),
          MessageInputBar(
            onSendMessage: _handleSendMessage,
            onSendVoiceMessage: _handleSendVoiceMessage,
          ),
        ],
      ),
    );
  }
}
