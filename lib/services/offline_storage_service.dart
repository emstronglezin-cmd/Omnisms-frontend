import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service de gestion du mode offline avancé
/// Utilise SharedPreferences pour le cache (IndexedDB sur web)
class OfflineStorageService {
  static final OfflineStorageService _instance = OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  // Clés de cache
  static const String _keyContacts = 'offline_contacts';
  static const String _keyMessages = 'offline_messages';
  static const String _keyGroups = 'offline_groups';
  static const String _keyUser = 'offline_user';
  static const String _keyLastSync = 'offline_last_sync';
  static const String _keyPendingActions = 'offline_pending_actions';

  // Durée de validité du cache (24 heures)
  static const Duration _cacheValidity = Duration(hours: 24);

  /// Sauvegarder les contacts
  Future<void> saveContacts(List<ContactModel> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = contacts.map((c) => c.toJson()).toList();
      await prefs.setString(_keyContacts, json.encode(jsonData));
      await _updateLastSync('contacts');
      debugPrint('✅ ${contacts.length} contacts sauvegardés offline');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde contacts: $e');
    }
  }

  /// Récupérer les contacts
  Future<List<ContactModel>> getContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyContacts);
      
      if (jsonString == null) return [];
      
      // Vérifier la validité du cache
      if (!await _isCacheValid('contacts')) {
        debugPrint('⚠️ Cache contacts expiré');
        return [];
      }
      
      final List<dynamic> jsonData = json.decode(jsonString);
      final contacts = jsonData.map((j) => ContactModel.fromJson(j)).toList();
      debugPrint('📥 ${contacts.length} contacts récupérés du cache');
      return contacts;
    } catch (e) {
      debugPrint('❌ Erreur récupération contacts: $e');
      return [];
    }
  }

  /// Sauvegarder les messages d'une conversation
  Future<void> saveMessages(String conversationId, List<MessageModel> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyMessages}_$conversationId';
      final jsonData = messages.map((m) => m.toJson()).toList();
      await prefs.setString(key, json.encode(jsonData));
      await _updateLastSync('messages_$conversationId');
      debugPrint('✅ ${messages.length} messages sauvegardés offline');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde messages: $e');
    }
  }

  /// Récupérer les messages d'une conversation
  Future<List<MessageModel>> getMessages(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyMessages}_$conversationId';
      final jsonString = prefs.getString(key);
      
      if (jsonString == null) return [];
      
      if (!await _isCacheValid('messages_$conversationId')) {
        debugPrint('⚠️ Cache messages expiré');
        return [];
      }
      
      final List<dynamic> jsonData = json.decode(jsonString);
      final messages = jsonData.map((j) => MessageModel.fromJson(j)).toList();
      debugPrint('📥 ${messages.length} messages récupérés du cache');
      return messages;
    } catch (e) {
      debugPrint('❌ Erreur récupération messages: $e');
      return [];
    }
  }

  /// Sauvegarder les groupes
  Future<void> saveGroups(List<GroupModel> groups) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = groups.map((g) => g.toJson()).toList();
      await prefs.setString(_keyGroups, json.encode(jsonData));
      await _updateLastSync('groups');
      debugPrint('✅ ${groups.length} groupes sauvegardés offline');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde groupes: $e');
    }
  }

  /// Récupérer les groupes
  Future<List<GroupModel>> getGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyGroups);
      
      if (jsonString == null) return [];
      
      if (!await _isCacheValid('groups')) {
        debugPrint('⚠️ Cache groupes expiré');
        return [];
      }
      
      final List<dynamic> jsonData = json.decode(jsonString);
      final groups = jsonData.map((j) => GroupModel.fromJson(j)).toList();
      debugPrint('📥 ${groups.length} groupes récupérés du cache');
      return groups;
    } catch (e) {
      debugPrint('❌ Erreur récupération groupes: $e');
      return [];
    }
  }

  /// Sauvegarder l'utilisateur
  Future<void> saveUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, json.encode(user.toJson()));
      await _updateLastSync('user');
      debugPrint('✅ Utilisateur sauvegardé offline');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde utilisateur: $e');
    }
  }

  /// Récupérer l'utilisateur
  Future<UserModel?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyUser);
      
      if (jsonString == null) return null;
      
      final user = UserModel.fromJson(json.decode(jsonString));
      debugPrint('📥 Utilisateur récupéré du cache');
      return user;
    } catch (e) {
      debugPrint('❌ Erreur récupération utilisateur: $e');
      return null;
    }
  }

  /// Ajouter une action en attente (pour sync ultérieure)
  Future<void> addPendingAction(Map<String, dynamic> action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyPendingActions) ?? '[]';
      final List<dynamic> actions = json.decode(jsonString);
      
      // Ajouter timestamp
      action['timestamp'] = DateTime.now().toIso8601String();
      actions.add(action);
      
      await prefs.setString(_keyPendingActions, json.encode(actions));
      debugPrint('✅ Action ajoutée à la file: ${action['type']}');
    } catch (e) {
      debugPrint('❌ Erreur ajout action: $e');
    }
  }

  /// Récupérer les actions en attente
  Future<List<Map<String, dynamic>>> getPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyPendingActions) ?? '[]';
      final List<dynamic> actions = json.decode(jsonString);
      return actions.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Erreur récupération actions: $e');
      return [];
    }
  }

  /// Supprimer une action traitée
  Future<void> removePendingAction(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyPendingActions) ?? '[]';
      final List<dynamic> actions = json.decode(jsonString);
      
      if (index < actions.length) {
        actions.removeAt(index);
        await prefs.setString(_keyPendingActions, json.encode(actions));
        debugPrint('✅ Action supprimée de la file');
      }
    } catch (e) {
      debugPrint('❌ Erreur suppression action: $e');
    }
  }

  /// Vider toutes les actions en attente
  Future<void> clearPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPendingActions, '[]');
      debugPrint('✅ File d\'actions vidée');
    } catch (e) {
      debugPrint('❌ Erreur vidage actions: $e');
    }
  }

  /// Mettre à jour la date de dernière synchronisation
  Future<void> _updateLastSync(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncKey = '${_keyLastSync}_$key';
      await prefs.setString(syncKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ Erreur mise à jour sync: $e');
    }
  }

  /// Vérifier si le cache est valide
  Future<bool> _isCacheValid(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncKey = '${_keyLastSync}_$key';
      final lastSyncString = prefs.getString(syncKey);
      
      if (lastSyncString == null) return false;
      
      final lastSync = DateTime.parse(lastSyncString);
      final now = DateTime.now();
      final difference = now.difference(lastSync);
      
      return difference < _cacheValidity;
    } catch (e) {
      debugPrint('❌ Erreur vérification cache: $e');
      return false;
    }
  }

  /// Obtenir la date de dernière synchronisation
  Future<DateTime?> getLastSyncDate(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncKey = '${_keyLastSync}_$key';
      final lastSyncString = prefs.getString(syncKey);
      
      if (lastSyncString == null) return null;
      return DateTime.parse(lastSyncString);
    } catch (e) {
      debugPrint('❌ Erreur récupération date sync: $e');
      return null;
    }
  }

  /// Vider tout le cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyContacts);
      await prefs.remove(_keyMessages);
      await prefs.remove(_keyGroups);
      await prefs.remove(_keyUser);
      await prefs.remove(_keyLastSync);
      debugPrint('✅ Cache vidé');
    } catch (e) {
      debugPrint('❌ Erreur vidage cache: $e');
    }
  }

  /// Obtenir la taille du cache (estimation)
  Future<Map<String, int>> getCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'contacts': prefs.getString(_keyContacts)?.length ?? 0,
        'messages': prefs.getString(_keyMessages)?.length ?? 0,
        'groups': prefs.getString(_keyGroups)?.length ?? 0,
        'user': prefs.getString(_keyUser)?.length ?? 0,
        'pending': prefs.getString(_keyPendingActions)?.length ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Erreur calcul taille cache: $e');
      return {};
    }
  }

  /// Synchroniser les actions en attente
  Future<void> syncPendingActions(
    Future<void> Function(Map<String, dynamic>) processor,
  ) async {
    final actions = await getPendingActions();
    
    if (actions.isEmpty) {
      debugPrint('✅ Aucune action en attente');
      return;
    }
    
    debugPrint('🔄 Synchronisation de ${actions.length} actions...');
    
    for (int i = actions.length - 1; i >= 0; i--) {
      try {
        await processor(actions[i]);
        await removePendingAction(i);
        debugPrint('✅ Action synchronisée: ${actions[i]['type']}');
      } catch (e) {
        debugPrint('❌ Erreur sync action: $e');
        // Laisser l'action dans la file pour retry
      }
    }
  }
}
