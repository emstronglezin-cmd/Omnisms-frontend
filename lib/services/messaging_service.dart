import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_service.dart';

/// MessagingService — All messaging API calls.
///
/// Endpoints used:
///   GET  /api/messages                    → conversation list
///   GET  /api/messages/:conversationId    → message history
///   POST /api/messages/send               → send message
///   POST /api/messages/:id/react          → emoji reaction
///   DELETE /api/messages/:id              → delete message
///   POST /api/messages/:id/read           → mark as read
///   POST /api/transcription               → transcribe voice
///
/// Real-time: polling via Timer (Socket.IO pkg not in pubspec).
/// The MessagingProvider manages a periodic Timer for conversation refresh.
class MessagingService {
  final AuthService _authService = AuthService();

  // ── Helper: build auth headers ──────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      ...ApiConfig.headers,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── GET /api/messages → conversations list ─────────────────
  Future<List<ConversationModel>> getConversations() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.conversationsEndpoint}'),
            headers: headers,
          )
          .timeout(ApiConfig.requestTimeout);

      debugPrint('[MessagingService] GET /api/messages → ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend may return { conversations: [...] } or { messages: [...] } or [...]
        List raw;
        if (data is List) {
          raw = data;
        } else if (data['conversations'] is List) {
          raw = data['conversations'] as List;
        } else if (data['messages'] is List) {
          raw = data['messages'] as List;
        } else {
          raw = [];
        }
        final conversations = raw
            .map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
            .toList();
        // Sort newest first
        conversations.sort((a, b) {
          final at = a.lastMessageTime;
          final bt = b.lastMessageTime;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
        debugPrint('[MessagingService] Got ${conversations.length} conversations');
        return conversations;
      }
      return [];
    } catch (e) {
      debugPrint('[MessagingService] getConversations error: $e');
      return [];
    }
  }

  // ── GET /api/messages/:conversationId → message history ─────
  Future<List<MessageModel>> getConversationHistory(
    String conversationId, {
    String? currentUserId,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}/$conversationId'),
            headers: headers,
          )
          .timeout(ApiConfig.requestTimeout);

      debugPrint(
          '[MessagingService] GET /api/messages/$conversationId → ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List raw;
        if (data is List) {
          raw = data;
        } else if (data['messages'] is List) {
          raw = data['messages'] as List;
        } else {
          raw = [];
        }

        final messages = raw.map((m) {
          final map = m as Map<String, dynamic>;
          if (currentUserId != null) {
            return MessageModel.fromJsonWithCurrentUser(map, currentUserId);
          }
          return MessageModel.fromJson(map);
        }).toList();

        // Sort oldest first (chat display order)
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        debugPrint('[MessagingService] Got ${messages.length} messages');
        return messages;
      }
      return [];
    } catch (e) {
      debugPrint('[MessagingService] getConversationHistory error: $e');
      return [];
    }
  }

  // ── POST /api/messages/send → send text message ─────────────
  Future<MessageModel?> sendTextMessage({
    required String receiverId,
    required String content,
    String? conversationId,
    String? currentUserId,
  }) async {
    final apiUrl = '${ApiConfig.baseUrl}${ApiConfig.sendMessageEndpoint}';
    debugPrint('[DEBUG_SEND] MessagingService sendTextMessage called');
    debugPrint('[DEBUG_SEND] API URL=$apiUrl');
    debugPrint('[DEBUG_SEND] receiverId=$receiverId, content=$content, conversationId=$conversationId');
    debugPrint('[DEBUG_SEND] HTTP request started POST $apiUrl');
    try {
      final headers = await _authHeaders();
      debugPrint('[DEBUG_SEND] headers prepared, hasAuth=${headers.containsKey("Authorization")}');

      final payload = {
        'receiverId': receiverId,
        'content': content,
        'type': 'text',
        if (conversationId != null) 'conversationId': conversationId,
      };
      debugPrint('[DEBUG_SEND] payload=${jsonEncode(payload)}');

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.requestTimeout);

      debugPrint('[DEBUG_SEND] HTTP status=${response.statusCode}');
      debugPrint('[MessagingService] POST /api/messages/send → ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[DEBUG_SEND] success, parsing body');
        final data = jsonDecode(response.body);
        final msgJson = data['message'] ?? data;
        if (currentUserId != null) {
          return MessageModel.fromJsonWithCurrentUser(
              msgJson as Map<String, dynamic>, currentUserId);
        }
        return MessageModel.fromJson(msgJson as Map<String, dynamic>);
      }
      debugPrint('[DEBUG_SEND] failed status=${response.statusCode}, body=${response.body}');
      debugPrint('[MessagingService] sendTextMessage failed: ${response.body}');
      return null;
    } catch (e, st) {
      debugPrint('[DEBUG_SEND] exception: $e');
      debugPrint('[DEBUG_SEND] stack: $st');
      debugPrint('[MessagingService] sendTextMessage error: $e');
      return null;
    }
  }

  // ── Messages vocaux — même flux que la PWA ───────────────────
  //
  // public/app.js (uploadVoiceMessage()) fait DEUX appels :
  //   1. POST /api/audio/upload  (multipart « audio ») → { id, url, duration, durationFormatted }
  //   2. POST /api/messages/send { receiverId, content: '', type: 'audio', audioUrl, duration }
  //      (ou POST /groups/:id/messages pour un groupe)
  //
  // L'URL renvoyée par le serveur peut être relative (/uploads/audio/…) :
  // on la garde BRUTE pour l'envoi (le backend la stocke telle quelle) et on
  // la résout en absolue uniquement pour le lecteur (ApiConfig.resolveMediaUrl).

  /// Étape 1 — upload du fichier audio.
  /// Retourne { id, url, duration, durationFormatted } ou null.
  Future<Map<String, dynamic>?> uploadAudio({
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    if ((filePath == null || filePath.isEmpty) &&
        (bytes == null || bytes.isEmpty)) {
      return null;
    }
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.audioUploadEndpoint}'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      final name = filename ?? 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      request.files.add(
        bytes != null && bytes.isNotEmpty
            ? http.MultipartFile.fromBytes('audio', bytes, filename: name)
            : await http.MultipartFile.fromPath('audio', filePath!, filename: name),
      );

      final streamed =
          await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return {
            'id': data['id'],
            'url': data['url'],
            'duration': data['duration'],
            'durationFormatted': data['durationFormatted'],
          };
        }
      }
      debugPrint('[MessagingService] uploadAudio failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[MessagingService] uploadAudio error: $e');
      return null;
    }
  }

  /// Étape 2 — envoi du message audio (conversation 1:1 ou groupe).
  Future<MessageModel?> sendAudioMessage({
    required String receiverId,
    required String audioUrl,
    int? duration,
    String? conversationId,
    String? currentUserId,
    bool isGroup = false,
  }) async {
    try {
      final headers = await _authHeaders();
      final path = isGroup
          ? '${ApiConfig.baseUrl}${ApiConfig.groupMessagesEndpoint(receiverId)}'
          : '${ApiConfig.baseUrl}${ApiConfig.sendMessageEndpoint}';

      final payload = <String, dynamic>{
        if (!isGroup) 'receiverId': receiverId,
        'content': '',
        'type': 'audio',
        'audioUrl': audioUrl,
        if (duration != null) 'duration': duration,
        if (conversationId != null) 'conversationId': conversationId,
      };

      final response = await http
          .post(Uri.parse(path), headers: headers, body: jsonEncode(payload))
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final msgJson = data is Map ? (data['message'] ?? data) : data;
        if (currentUserId != null) {
          return MessageModel.fromJsonWithCurrentUser(
              msgJson as Map<String, dynamic>, currentUserId);
        }
        return MessageModel.fromJson(msgJson as Map<String, dynamic>);
      }
      debugPrint('[MessagingService] sendAudioMessage failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[MessagingService] sendAudioMessage error: $e');
      return null;
    }
  }

  /// Envoi complet d'un message vocal : upload puis envoi.
  ///
  /// Retourne { message, audioUrl } où `audioUrl` est l'URL résolue
  /// (absolute) utilisable par le lecteur — idem PWA.
  /// Repli sur l'ancien envoi multipart si l'upload échoue.
  Future<Map<String, dynamic>?> sendVoiceMessage({
    required String receiverId,
    required dynamic audioFile,
    int? duration,
    String? conversationId,
    String? currentUserId,
    bool isGroup = false,
  }) async {
    final String? filePath =
        audioFile is String ? audioFile : (audioFile?.path?.toString());

    final uploaded = await uploadAudio(filePath: filePath);
    if (uploaded != null && (uploaded['url'] ?? '').toString().isNotEmpty) {
      final rawUrl = uploaded['url'].toString();
      final message = await sendAudioMessage(
        receiverId: receiverId,
        audioUrl: rawUrl,
        duration: (uploaded['duration'] as num?)?.round() ?? duration,
        conversationId: conversationId,
        currentUserId: currentUserId,
        isGroup: isGroup,
      );
      if (message != null) {
        return {
          'message': message,
          'audioUrl': ApiConfig.resolveMediaUrl(rawUrl),
          'duration': (uploaded['duration'] as num?)?.round() ?? duration,
          'durationFormatted': uploaded['durationFormatted']?.toString(),
        };
      }
    }

    // ── Repli : ancien envoi multipart direct ──────────────────
    if (filePath == null || filePath.isEmpty) return null;
    try {
      final token = await _authService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sendMessageEndpoint}'),
      );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields['receiverId'] = receiverId;
      request.fields['type'] = 'audio';
      if (duration != null) request.fields['duration'] = duration.toString();
      if (conversationId != null) {
        request.fields['conversationId'] = conversationId;
      }
      request.files.add(await http.MultipartFile.fromPath('audio', filePath));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final msgJson = data is Map ? (data['message'] ?? data) : data;
        final message = currentUserId != null
            ? MessageModel.fromJsonWithCurrentUser(
                msgJson as Map<String, dynamic>, currentUserId)
            : MessageModel.fromJson(msgJson as Map<String, dynamic>);
        return {
          'message': message,
          'audioUrl': message.playableAudioUrl,
          'duration': duration,
        };
      }
      return null;
    } catch (e) {
      debugPrint('[MessagingService] sendVoiceMessage fallback error: $e');
      return null;
    }
  }

  // ── Transcription (contrat PWA : /api/audio/…) ───────────────
  /// Lance la transcription : POST /api/audio/transcribe/:messageId
  Future<bool> startTranscription(String messageId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.audioTranscribeEndpoint(messageId)}'),
            headers: headers,
            body: jsonEncode({'language': 'fr'}),
          )
          .timeout(const Duration(seconds: 60));
      return response.statusCode == 200 || response.statusCode == 202;
    } catch (e) {
      debugPrint('[MessagingService] startTranscription error: $e');
      return false;
    }
  }

  /// Statut/ résultat : GET /api/audio/:messageId
  /// → { transcriptionStatus: pending|processing|done|error, transcription }
  Future<Map<String, dynamic>?> getAudioMessage(String messageId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.audioMessageEndpoint(messageId)}'),
            headers: headers,
          )
          .timeout(ApiConfig.requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
      return null;
    } catch (e) {
      debugPrint('[MessagingService] getAudioMessage error: $e');
      return null;
    }
  }

  // ── Legacy: getMessages by contactId (kept for backward compat) ──
  Future<List<MessageModel>> getMessages({
    required String contactId,
    int? limit = 50,
    int? offset = 0,
    String? currentUserId,
  }) async {
    // Treat contactId as conversationId → use new endpoint
    return getConversationHistory(contactId, currentUserId: currentUserId);
  }

  // ── POST /api/messages/:id/react ────────────────────────────
  Future<bool> reactToMessage(String messageId, String emoji) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}/$messageId/react'),
            headers: headers,
            body: jsonEncode({'emoji': emoji}),
          )
          .timeout(ApiConfig.requestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[MessagingService] reactToMessage error: $e');
      return false;
    }
  }

  // ── DELETE /api/messages/:id ──────────────────────────────────
  Future<bool> deleteMessage(String messageId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}/$messageId'),
            headers: headers,
          )
          .timeout(ApiConfig.requestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[MessagingService] deleteMessage error: $e');
      return false;
    }
  }

  // ── Transcription (route historique, conservée en repli) ─────
  Future<String?> transcribeVoiceMessage(String messageId) async {
    final started = await startTranscription(messageId);
    if (started) {
      final audio = await getAudioMessage(messageId);
      final txt = audio?['transcription']?.toString();
      if (txt != null && txt.isNotEmpty) return txt;
    }
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.transcriptionEndpoint}'),
            headers: headers,
            body: jsonEncode({'messageId': messageId}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['transcription'] ?? data['text'];
      }
      return null;
    } catch (e) {
      debugPrint('[MessagingService] transcribeVoiceMessage error: $e');
      return null;
    }
  }

  // ── POST /api/messages/:id/read ───────────────────────────────
  Future<bool> markAsRead(String messageId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}/$messageId/read'),
            headers: headers,
          )
          .timeout(ApiConfig.requestTimeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[MessagingService] markAsRead error: $e');
      return false;
    }
  }

  // ── Stub: WebSocket (kept for API compat, replaced by polling) ──
  void connectWebSocket(Function(MessageModel) onMessageReceived) {
    debugPrint('[MessagingService] WebSocket stub — using polling instead');
  }

  void disconnectWebSocket() {
    debugPrint('[MessagingService] disconnectWebSocket stub');
  }
}
