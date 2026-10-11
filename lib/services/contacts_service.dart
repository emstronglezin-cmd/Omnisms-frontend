import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
// flutter_contacts is mobile-only — replaced by stub on web
import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'native_contacts_service.dart';

class ContactsService {
  final AuthService _authService = AuthService();

  final NativeContactsService _nativeContacts = NativeContactsService();

  // Request contacts permission
  Future<bool> requestContactsPermission() async {
    if (kIsWeb) return false;
    final status = await _nativeContacts.requestPermission();
    return status == NativeContactsPermission.granted;
  }

  /// Lit le carnet d'adresses de l'appareil (flutter_contacts).
  /// Renvoie une liste vide sur le web : il n'y a pas d'API contacts.
  Future<List<ContactModel>> getPhoneContacts() async {
    if (kIsWeb) {
      debugPrint('⚠️ getPhoneContacts: not available on web');
      return [];
    }
    try {
      final entries = await _nativeContacts.fetchContacts();
      return entries
          .map((e) => ContactModel(id: e.phone, name: e.name, phone: e.phone))
          .toList();
    } catch (e) {
      debugPrint('Error reading device contacts: $e');
      return [];
    }
  }

  // Sync contacts with backend
  Future<List<ContactModel>> syncContacts(List<ContactModel> phoneContacts) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return phoneContacts;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}/sync'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'contacts': phoneContacts.map((c) => c.toJson()).toList(),
        }),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List contacts = data['contacts'] ?? [];
        return contacts.map((c) => ContactModel.fromJson(c)).toList();
      }
      return phoneContacts;
    } catch (e) {
      debugPrint('Error syncing contacts: $e');
      return phoneContacts;
    }
  }

  // Get contacts from backend
  Future<List<ContactModel>> getContacts() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}'),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List contacts = data['contacts'] ?? data;
        return contacts.map((c) => ContactModel.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting contacts: $e');
      return [];
    }
  }

  // Search contacts
  Future<List<ContactModel>> searchContacts(String query) async {
    try {
      final token = await _authService.getToken();
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}/search?q=$query'),
        headers: token != null ? {
          ...ApiConfig.headers,
          'Authorization': 'Bearer $token',
        } : ApiConfig.headers,
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List contacts = data['contacts'] ?? data;
        return contacts.map((c) => ContactModel.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching contacts: $e');
      return [];
    }
  }
}
