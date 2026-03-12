enum MessageType {
  text,
  voice,
  image,
  video,
  file,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String? receiverId;
  final MessageType type;
  final String? content; // For text messages
  final String? mediaUrl; // For voice, image, video, file
  final String? transcription; // For voice messages
  final int? duration; // For voice messages (in seconds)
  final MessageStatus status;
  final DateTime timestamp;
  final bool isMe;
  final String? reaction; // Emoji reaction

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    this.receiverId,
    required this.type,
    this.content,
    this.mediaUrl,
    this.transcription,
    this.duration,
    required this.status,
    required this.timestamp,
    required this.isMe,
    this.reaction,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? json['_id'] ?? '',
      conversationId: json['conversationId'] ?? json['conversation_id'] ?? '',
      senderId: json['senderId'] ?? json['sender_id'] ?? '',
      senderName: json['senderName'] ?? json['sender_name'],
      receiverId: json['receiverId'] ?? json['receiver_id'],
      type: _parseMessageType(json['type']),
      content: json['content'],
      mediaUrl: json['mediaUrl'] ?? json['media_url'],
      transcription: json['transcription'],
      duration: json['duration'],
      status: _parseMessageStatus(json['status']),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isMe: json['isMe'] ?? json['is_me'] ?? false,
      reaction: json['reaction'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'type': type.name,
      'content': content,
      'mediaUrl': mediaUrl,
      'transcription': transcription,
      'duration': duration,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe,
      'reaction': reaction,
    };
  }

  static MessageType _parseMessageType(dynamic type) {
    if (type == null) return MessageType.text;
    if (type is MessageType) return type;
    switch (type.toString().toLowerCase()) {
      case 'voice':
      case 'audio':
        return MessageType.voice;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }

  static MessageStatus _parseMessageStatus(dynamic status) {
    if (status == null) return MessageStatus.sent;
    if (status is MessageStatus) return status;
    switch (status.toString().toLowerCase()) {
      case 'sending':
        return MessageStatus.sending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? receiverId,
    MessageType? type,
    String? content,
    String? mediaUrl,
    String? transcription,
    int? duration,
    MessageStatus? status,
    DateTime? timestamp,
    bool? isMe,
    String? reaction,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      transcription: transcription ?? this.transcription,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      reaction: reaction ?? this.reaction,
    );
  }
}
