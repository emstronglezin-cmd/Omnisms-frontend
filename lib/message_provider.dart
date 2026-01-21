// lib/message_provider.dart

class Message {
  final String content;      // le texte du message
  final String sender;       // l'expéditeur (ex: "Moi" ou "Alice")
  final DateTime timestamp;  // l'heure d'envoi
  final bool isMe;           // pour savoir si c'est l'utilisateur ou non

  Message({
    required this.content,
    required this.sender,
    required this.timestamp,
    required this.isMe,
  });

  /// Crée un Message à partir d'un JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      content: json['content'] ?? '',
      sender: json['sender'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isMe: json['isMe'] ?? false,
    );
  }

  /// Convertit un Message en JSON
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'sender': sender,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe,
    };
  }
}
