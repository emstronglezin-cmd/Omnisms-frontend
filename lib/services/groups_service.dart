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
        // La PWA envoie `members` (public/app.js — createGroup()) :
        // c'est le champ attendu par le backend.
        body: jsonEncode({
          'name': name,
          'description': description,
          'members': memberIds,
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

  /// Ajoute un membre par identifiant générique.
  ///
  /// Le backend résout indifféremment un numéro de téléphone, un @username
  /// ou un UID (userResolver) — c'est ce que fait la PWA avec
  /// POST /groups/:id/members { identifier }.
  Future<bool> addMemberByIdentifier(String groupId, String identifier) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupMembersEndpoint(groupId)}'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'identifier': identifier}),
      ).timeout(ApiConfig.requestTimeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding member by identifier: $e');
      return false;
    }
  }

  /// Ajoute un membre par UID (alias conservé pour compatibilité).
  Future<bool> addMember(String groupId, String userId) async {
    final ok = await addMemberByIdentifier(groupId, userId);
    if (ok) return true;

    // Repli : ancien format { userId } / { members: [uid] }.
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupMembersEndpoint(groupId)}'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': userId, 'members': [userId]}),
      ).timeout(ApiConfig.requestTimeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error adding member: $e');
      return false;
    }
  }

  /// Transfère le rôle d'administrateur — PUT /groups/:id/admin { newOwner }.
  /// (PWA : transferAdmin())
  Future<bool> transferAdmin(String groupId, String newOwnerId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupAdminEndpoint(groupId)}'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'newOwner': newOwnerId}),
      ).timeout(ApiConfig.requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error transferring admin: $e');
      return false;
    }
  }

  /// Upload de la photo du groupe — POST /groups/:id/avatar (champ « image »).
  /// (PWA : saveGroupEdits())
  Future<String?> uploadGroupAvatar({
    required String groupId,
    List<int>? bytes,
    String? filePath,
    String? filename,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return null;
      if ((bytes == null || bytes.isEmpty) && (filePath == null || filePath.isEmpty)) {
        return null;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.groupAvatarEndpoint(groupId)}'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      final name = filename ?? 'group.jpg';
      request.files.add(
        bytes != null && bytes.isNotEmpty
            ? http.MultipartFile.fromBytes('image', bytes, filename: name)
            : await http.MultipartFile.fromPath('image', filePath!, filename: name),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          return (data['image'] ?? data['avatarUrl'] ?? data['url'])?.toString();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading group avatar: $e');
      return null;
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
        return members.map((m) {
          if (m is Map<String, dynamic>) return m;
          if (m is Map) return Map<String, dynamic>.from(m);
          // Ancien format : tableau d'UID.
          return <String, dynamic>{'uid': m.toString()};
        }).toList();
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
