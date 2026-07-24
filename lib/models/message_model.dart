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

  /// Build a MessageModel from backend JSON.
  ///
  /// isMe computation priority:
  ///   1. Explicit `isMe` / `is_me` field in JSON (set by caller).
  ///   2. Explicit `currentUserId` field set by the caller after fetch.
  ///   3. Fallback: false.
  ///
  /// Use [fromJsonWithCurrentUser] for automatic senderId comparison.
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Timestamp: prefer 'timestamp', then 'createdAt', then now
    DateTime ts = DateTime.now();
    final rawTs = json['timestamp'] ?? json['createdAt'] ?? json['created_at'];
    if (rawTs != null) {
      try {
        ts = DateTime.parse(rawTs.toString());
      } catch (_) {
        ts = DateTime.now();
      }
    }

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
      duration: json['duration'] is int
          ? json['duration']
          : int.tryParse(json['duration']?.toString() ?? ''),
      status: _parseMessageStatus(json['status']),
      timestamp: ts,
      // isMe: explicit flag from server or caller injection wins
      isMe: json['isMe'] ?? json['is_me'] ?? false,
      reaction: json['reaction'],
    );
  }

  /// Build from JSON with current user ID for proper isMe computation.
  factory MessageModel.fromJsonWithCurrentUser(
    Map<String, dynamic> json,
    String currentUserId,
  ) {
    final base = MessageModel.fromJson(json);
    final senderId = json['senderId'] ?? json['sender_id'] ?? '';
    final isMe = senderId == currentUserId;
    return base.copyWith(isMe: isMe);
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
