import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_service.dart';

class GroupsService {
  final AuthService _authService = AuthService();

  // Get all groups
  Future<List<GroupModel>> getGroups() async {
    try {
      final token = await _authService.getToken();

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupsEndpoint}'),
        headers: token != null ? {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        } : ApiConfig.headers,
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List groups = data['groups'] ?? data;
        return groups.map((g) => GroupModel.fromJson(g)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting groups: $e');
      return [];
    }
  }

  // Create group
  Future<GroupModel?> createGroup({
    required String name,
    String? description,
    required List<String> memberIds,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupsEndpoint}'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'memberIds': memberIds,
        }),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return GroupModel.fromJson(data['group'] ?? data);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating group: $e');
      return null;
    }
  }

  // Update group
  Future<GroupModel?> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? photoUrl,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupsEndpoint}/$groupId'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (photoUrl != null) 'photoUrl': photoUrl,
        }),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GroupModel.fromJson(data['group'] ?? data);
      }
      return null;
    } catch (e) {
      debugPrint('Error updating group: $e');
      return null;
    }
  }

  // Add member to group
  Future<bool> addMember(String groupId, String userId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupsEndpoint}/$groupId/members'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': userId}),
      ).timeout(ApiConfig.requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error adding member: $e');
      return false;
    }
  }

  // Remove member from group
  Future<bool> removeMember(String groupId, String userId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupsEndpoint}/$groupId/members/$userId'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removing member: $e');
      return false;
    }
  }

  // Delete group
  Future<bool> deleteGroup(String groupId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupsEndpoint}/$groupId'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting group: $e');
      return false;
    }
  }

  // Get group members (enriched with names/avatars from backend)
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupsEndpoint}/$groupId/members'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List members = data['members'] ?? [];
        return members.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting group members: $e');
      return [];
    }
  }

  // Get group messages
  Future<List<MessageModel>> getGroupMessages(String groupId) async {
    try {
      final token = await _authService.getToken();

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupsEndpoint}/$groupId/messages'),
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
      debugPrint('Error getting group messages: $e');
      return [];
    }
  }

  // Send message to group
  Future<MessageModel?> sendGroupMessage({
    required String groupId,
    required String content,
    String type = 'text',
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupsEndpoint}/$groupId/messages'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'content': content,
          'type': type,
        }),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return MessageModel.fromJson(data['message'] ?? data);
      }
      return null;
    } catch (e) {
      debugPrint('Error sending group message: $e');
      return null;
    }
  }
}
