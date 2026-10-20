import '../config/api_config.dart';

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
  final String? audioUrl; // Raw audio URL as returned by the backend (relative or absolute)
  final String? transcription; // For voice messages
  final String? transcriptionStatus; // pending | processing | done | error
  final String? transcriptionError;
  final int? duration; // For voice messages (in seconds)
  final String? durationFormatted; // '0:42' — affichage direct quand fourni par le backend
  final MessageStatus status;
  final DateTime timestamp;
  final bool isMe;
  final String? reaction; // Emoji reaction

  /// Canal réellement utilisé par le backend pour acheminer le message.
  ///
  /// `'app'` → message interne OmniSMS (Socket.IO, gratuit) ;
  /// `'sms'` → SMS externe (le destinataire n'avait pas de session active).
  ///
  /// Renseigné par `POST /api/messages/send` (`message.channel`) et par les
  /// conversations/distances renvoyées par le backend. `null` = inconnu
  /// (ancien document ou message local en cours d'envoi) : l'IHM n'affiche
  /// alors aucun badge plutôt que d'inventer un état.
  final String? channel;

  /// Identifiant local temporaire (optimistic UI) avant réponse du backend.
  final String? tempId;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    this.receiverId,
    required this.type,
    this.content,
    this.mediaUrl,
    this.audioUrl,
    this.transcription,
    this.transcriptionStatus,
    this.transcriptionError,
    this.duration,
    this.durationFormatted,
    required this.status,
    required this.timestamp,
    required this.isMe,
    this.reaction,
    this.channel,
    this.tempId,
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
      mediaUrl: json['mediaUrl'] ?? json['media_url'] ?? json['audioUrl'] ?? json['url'],
      audioUrl: json['audioUrl'] ?? json['audio_url'] ?? json['url'],
      transcription: json['transcription'],
      transcriptionStatus: (json['transcriptionStatus'] ?? json['transcription_status'])
          ?.toString(),
      transcriptionError: (json['transcriptionError'] ?? json['transcription_error'])
          ?.toString(),
      durationFormatted: (json['durationFormatted'] ?? json['duration_formatted'])
          ?.toString(),
      duration: json['duration'] is int
          ? json['duration']
          : int.tryParse(json['duration']?.toString() ?? ''),
      status: _parseMessageStatus(json['status']),
      timestamp: ts,
      // isMe: explicit flag from server or caller injection wins
      isMe: json['isMe'] ?? json['is_me'] ?? false,
      reaction: json['reaction'],
      channel: _normalizeChannel(json['channel'] ?? json['route']),
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

  /// Normalise le canal renvoyé par le backend.
  ///
  /// Le backend expose `channel` ('app' | 'sms') et, pour l'envoi, `route`
  /// ('OMNISMS' | 'INFOBIP' | 'ERROR'). Toute autre valeur → `null`
  /// (inconnu) : jamais d'état inventé.
  static String? _normalizeChannel(Object? value) {
    final raw = value?.toString().trim().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    if (raw == 'app' || raw == 'omnisms' || raw == 'internal' || raw == 'in_app') {
      return 'app';
    }
    if (raw == 'sms' || raw == 'infobip' || raw == 'external' || raw == 'sms_fallback') {
      return 'sms';
    }
    return null;
  }

  /// `true` quand le message est passé par le réseau SMS (et non par OmniSMS).
  bool get isSms => channel == 'sms';

  /// `true` quand le message est un message interne OmniSMS.
  bool get isInternal => channel == 'app';

  /// URL audio exploitable par le lecteur.
  ///
  /// Le backend stocke parfois un chemin relatif (/uploads/audio/…) : on le
  /// résout sur l'URL du backend, exactement comme la PWA
  /// (`renderAudioMessage` / `uploadVoiceMessage` dans public/app.js).
  String get playableAudioUrl =>
      ApiConfig.resolveMediaUrl(audioUrl ?? mediaUrl);

  bool get isAudio => type == MessageType.voice;

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
      'audioUrl': audioUrl,
      'transcription': transcription,
      'transcriptionStatus': transcriptionStatus,
      'transcriptionError': transcriptionError,
      'durationFormatted': durationFormatted,
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
    String? audioUrl,
    String? transcription,
    String? transcriptionStatus,
    String? transcriptionError,
    int? duration,
    String? durationFormatted,
    MessageStatus? status,
    DateTime? timestamp,
    bool? isMe,
    String? reaction,
    String? channel,
    String? tempId,
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
      audioUrl: audioUrl ?? this.audioUrl,
      transcription: transcription ?? this.transcription,
      transcriptionStatus: transcriptionStatus ?? this.transcriptionStatus,
      transcriptionError: transcriptionError ?? this.transcriptionError,
      duration: duration ?? this.duration,
      durationFormatted: durationFormatted ?? this.durationFormatted,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      reaction: reaction ?? this.reaction,
      channel: channel ?? this.channel,
      tempId: tempId ?? this.tempId,
    );
  }
}
