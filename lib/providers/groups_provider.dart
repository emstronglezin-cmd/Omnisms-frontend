import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/groups_service.dart';

class GroupsProvider with ChangeNotifier {
  final GroupsService _groupsService = GroupsService();

  List<GroupModel> _groups = [];
  bool _isLoading = false;
  String? _error;

  List<GroupModel> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadGroups() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _groups = await _groupsService.getGroups();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des groupes: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGroup({
    required String name,
    String? description,
    required List<String> memberIds,
  }) async {
    final group = await createGroupAndReturn(
      name: name,
      description: description,
      memberIds: memberIds,
    );
    return group != null;
  }

  /// Creates a group and returns the GroupModel (or null on failure).
  Future<GroupModel?> createGroupAndReturn({
    required String name,
    String? description,
    required List<String> memberIds,
  }) async {
    try {
      final group = await _groupsService.createGroup(
        name: name,
        description: description,
        memberIds: memberIds,
      );

      if (group != null) {
        _groups.insert(0, group);
        notifyListeners();
        return group;
      }
      return null;
    } catch (e) {
      _error = 'Erreur lors de la création du groupe: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> addMember(String groupId, String userId) async {
    try {
      final success = await _groupsService.addMember(groupId, userId);
      if (success) {
        await loadGroups(); // Reload to get updated group
      }
      return success;
    } catch (e) {
      _error = 'Erreur lors de l\'ajout du membre: $e';
      notifyListeners();
      return false;
    }
  }

  /// Ajoute un membre à partir d'un numéro de téléphone, d'un @username
  /// ou d'un UID — le backend fait la résolution (idem PWA).
  Future<bool> addMemberByIdentifier(String groupId, String identifier) async {
    try {
      final success =
          await _groupsService.addMemberByIdentifier(groupId, identifier);
      if (success) {
        await loadGroups();
      }
      return success;
    } catch (e) {
      _error = "Erreur lors de l'ajout du membre: $e";
      notifyListeners();
      return false;
    }
  }

  /// Transfère le rôle d'administrateur (PUT /groups/:id/admin).
  Future<bool> transferAdmin(String groupId, String newOwnerId) async {
    try {
      final success = await _groupsService.transferAdmin(groupId, newOwnerId);
      if (success) {
        await loadGroups();
      }
      return success;
    } catch (e) {
      _error = 'Erreur lors du transfert: $e';
      notifyListeners();
      return false;
    }
  }

  /// Upload de la photo du groupe (POST /groups/:id/avatar).
  Future<bool> uploadGroupAvatar({
    required String groupId,
    List<int>? bytes,
    String? filePath,
    String? filename,
  }) async {
    try {
      final url = await _groupsService.uploadGroupAvatar(
        groupId: groupId,
        bytes: bytes,
        filePath: filePath,
        filename: filename,
      );
      if (url != null) {
        await loadGroups();
        return true;
      }
      return false;
    } catch (e) {
      _error = "Erreur lors de l'upload de la photo: $e";
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(String groupId, String userId) async {
    try {
      final success = await _groupsService.removeMember(groupId, userId);
      if (success) {
        await loadGroups(); // Reload to get updated group
      }
      return success;
    } catch (e) {
      _error = 'Erreur lors de la suppression du membre: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGroup(String groupId, {String? name, String? description}) async {
    try {
      final group = await _groupsService.updateGroup(
        groupId: groupId,
        name: name,
        description: description,
      );

      if (group != null) {
        final index = _groups.indexWhere((g) => g.id == groupId);
        if (index != -1) {
          _groups[index] = group;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Erreur lors de la mise à jour du groupe: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    try {
      final success = await _groupsService.deleteGroup(groupId);
      if (success) {
        _groups.removeWhere((g) => g.id == groupId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Erreur lors de la suppression du groupe: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
