import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_service.dart';

class MessagingService {
  final AuthService _authService = AuthService();
  WebSocketChannel? _channel;

  // Send text message
  Future<MessageModel?> sendTextMessage({
    required String receiverId,
    required String content,
    String? conversationId,
  }) async {
    try {
      final token = await _authService.getToken();
      final userId = await _authService.getUserId();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sendMessageEndpoint}'),
        headers: token != null ? {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        } : ApiConfig.headers,
        body: jsonEncode({
          'receiverId': receiverId,
          'content': content,
          'type': 'text',
          if (conversationId != null) 'conversationId': conversationId,
        }),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return MessageModel.fromJson(data['message'] ?? data);
      }
      return null;
    } catch (e) {
      print('Error sending text message: $e');
      return null;
    }
  }

  // Send voice message
  Future<MessageModel?> sendVoiceMessage({
    required String receiverId,
    required File audioFile,
    int? duration,
    String? conversationId,
  }) async {
    try {
      final token = await _authService.getToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sendMessageEndpoint}'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['receiverId'] = receiverId;
      request.fields['type'] = 'voice';
      if (duration != null) request.fields['duration'] = duration.toString();
      if (conversationId != null) request.fields['conversationId'] = conversationId;

      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFile.path),
      );

      final streamedResponse = await request.send().timeout(
        Duration(seconds: 60), // Longer timeout for file upload
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return MessageModel.fromJson(data['message'] ?? data);
      }
      return null;
    } catch (e) {
      print('Error sending voice message: $e');
      return null;
    }
  }

  // Get messages for a conversation
  Future<List<MessageModel>> getMessages({
    required String contactId,
    int? limit = 50,
    int? offset = 0,
  }) async {
    try {
      final token = await _authService.getToken();

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}?contactId=$contactId&limit=$limit&offset=$offset'),
        headers: token != null ? {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        } : ApiConfig.headers,
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List messages = data['messages'] ?? data;
        return messages.map((m) => MessageModel.fromJson(m)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  // React to message (emoji)
  Future<bool> reactToMessage(String messageId, String emoji) async {
    try {
      final token = await _authService.getToken();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}/$messageId/react'),
        headers: token != null ? {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        } : ApiConfig.headers,
        body: jsonEncode({'emoji': emoji}),
      ).timeout(ApiConfig.requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error reacting to message: $e');
      return false;
    }
  }

  // Delete message
  Future<bool> deleteMessage(String messageId) async {
    try {
      final token = await _authService.getToken();

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}/$messageId'),
        headers: token != null ? {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        } : ApiConfig.headers,
      ).timeout(ApiConfig.requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // Transcribe voice message
  Future<String?> transcribeVoiceMessage(String messageId) async {
    try {
      final token = await _authService.getToken();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.transcriptionEndpoint}'),
        headers: token != null ? {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        } : ApiConfig.headers,
        body: jsonEncode({'messageId': messageId}),
      ).timeout(Duration(seconds: 60)); // Longer timeout for transcription

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['transcription'] ?? data['text'];
      }
      return null;
    } catch (e) {
      print('Error transcribing message: $e');
      return null;
    }
  }

  // WebSocket connection for real-time messaging
  void connectWebSocket(Function(MessageModel) onMessageReceived) async {
    try {
      final token = await _authService.getToken();
      final wsUrl = token != null 
          ? '${ApiConfig.wsUrl}?token=$token'
          : ApiConfig.wsUrl;

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'message') {
              final msg = MessageModel.fromJson(data['data'] ?? data);
              onMessageReceived(msg);
            }
          } catch (e) {
            print('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket closed');
        },
      );
    } catch (e) {
      print('Error connecting WebSocket: $e');
    }
  }

  void disconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;
  }

  // Mark message as read
  Future<bool> markAsRead(String messageId) async {
    try {
      final token = await _authService.getToken();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.messagesEndpoint}/$messageId/read'),
        headers: token != null ? {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        } : ApiConfig.headers,
      ).timeout(ApiConfig.requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking message as read: $e');
      return false;
    }
  }
}
