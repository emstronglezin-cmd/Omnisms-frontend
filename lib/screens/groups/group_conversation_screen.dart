import 'package:flutter/material.dart';
import '../messaging/widgets/message_bubble.dart';
import '../messaging/widgets/message_input_bar.dart';

class GroupConversationScreen extends StatefulWidget {
  final String? groupName;
  const GroupConversationScreen({super.key, this.groupName});

  @override
  State<GroupConversationScreen> createState() =>
      _GroupConversationScreenState();
}

class _GroupConversationScreenState extends State<GroupConversationScreen> {
  final List<Map<String, dynamic>> messages = [
    {
      'text': 'Salut le groupe!',
      'sender': 'Alice',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 10)),
      'isVoice': false,
    },
    {
      'text': 'Coucou!',
      'sender': 'Bob',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 8)),
      'isVoice': false,
    },
    {
      'text': 'Comment ça va?',
      'sender': 'Charlie',
      'isMe': false,
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      'isVoice': false,
    },
  ];

  void _handleSendMessage(String message) {
    setState(() {
      messages.add({
        'text': message,
        'sender': 'Vous',
        'isMe': true,
        'timestamp': DateTime.now(),
        'isVoice': false,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName ?? 'Groupe'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Infos du groupe'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Groupe: ${widget.groupName}'),
                      const SizedBox(height: 8),
                      const Text('Membres: 8'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              );
            },
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
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: message['isMe']
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!message['isMe'])
                        Text(
                          message['sender'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      MessageBubble(
                        text: message['text'],
                        isMe: message['isMe'],
                        timestamp: message['timestamp'],
                        isVoice: message['isVoice'],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          MessageInputBar(
            onSendMessage: _handleSendMessage,
            onSendVoiceMessage: (path) {},
          ),
        ],
      ),
    );
  }
}
