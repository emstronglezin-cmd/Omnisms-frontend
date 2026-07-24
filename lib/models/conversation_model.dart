/// ConversationModel — represents a conversation entry in the Messages list.
///
/// Fields come from GET /api/messages (conversation list endpoint).
/// Backend returns: id, otherUserId, otherUserName, lastMessage,
///   lastMessageTime, unreadCount, channel, isGroup.
class ConversationModel {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String channel; // 'whatsapp', 'sms', 'email', 'internal'
  final bool isGroup;
  final String? groupName;

  ConversationModel({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.channel = 'internal',
    this.isGroup = false,
    this.groupName,
  });

  /// Display name: group name if group, otherwise other user name
  String get displayName => isGroup ? (groupName ?? otherUserName) : otherUserName;

  /// Initials for avatar fallback
  String get initials {
    final name = displayName;
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // Parse lastMessageTime — backend may send 'lastMessageTime' or 'updatedAt' or 'createdAt'
    DateTime? lastTime;
    final rawTime = json['lastMessageTime'] ??
        json['lastMessage']?['createdAt'] ??
        json['updatedAt'] ??
        json['createdAt'];
    if (rawTime != null) {
      try {
        lastTime = DateTime.parse(rawTime.toString());
      } catch (_) {
        lastTime = null;
      }
    }

    // Parse lastMessage content
    String? lastMsgContent;
    final lastMsg = json['lastMessage'];
    if (lastMsg is Map) {
      lastMsgContent = lastMsg['content'] as String?;
    } else if (lastMsg is String) {
      lastMsgContent = lastMsg;
    }

    return ConversationModel(
      id: json['id'] ?? json['_id'] ?? json['conversationId'] ?? '',
      otherUserId: json['otherUserId'] ?? json['contactId'] ?? '',
      otherUserName: json['otherUserName'] ??
          json['contactName'] ??
          json['name'] ??
          'Utilisateur',
      otherUserPhotoUrl:
          json['otherUserPhotoUrl'] ?? json['photoUrl'] ?? json['photo_url'],
      lastMessage: lastMsgContent,
      lastMessageTime: lastTime,
      unreadCount: (json['unreadCount'] ?? json['unread_count'] ?? 0) as int,
      channel: json['channel'] ?? 'internal',
      isGroup: json['isGroup'] ?? json['is_group'] ?? false,
      groupName: json['groupName'] ?? json['group_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserPhotoUrl': otherUserPhotoUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
      'channel': channel,
      'isGroup': isGroup,
      'groupName': groupName,
    };
  }

  ConversationModel copyWith({
    String? id,
    String? otherUserId,
    String? otherUserName,
    String? otherUserPhotoUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? channel,
    bool? isGroup,
    String? groupName,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserPhotoUrl: otherUserPhotoUrl ?? this.otherUserPhotoUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      channel: channel ?? this.channel,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
    );
  }
}
