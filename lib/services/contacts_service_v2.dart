import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// flutter_contacts is mobile-only — not imported here (kIsWeb guards all calls)
import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_service.dart';

class ContactsServiceV2 {
  final AuthService _authService = AuthService();

  /// Normalize phone number to international format
  String normalizePhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Remove leading zeros
    cleaned = cleaned.replaceFirst(RegExp(r'^0+'), '');
    
    // Add + if not present and number is long enough
    if (!cleaned.startsWith('+') && cleaned.length >= 10) {
      // Default to adding + for international format
      cleaned = '+$cleaned';
    }
    
    return cleaned;
  }

  /// Get all phone contacts from device
  /// Returns empty list on web — device contacts not available in browser
  Future<List<ContactModel>> getPhoneContacts() async {
    if (kIsWeb) {
      debugPrint('⚠️ getPhoneContacts: not available on web');
      return [];
    }
    // Mobile implementation would use flutter_contacts here
    debugPrint('⚠️ getPhoneContacts: mobile stub, returning empty');
    return [];
  }

  /// Sync contacts with backend
  Future<List<ContactModel>> syncContacts(List<ContactModel> phoneContacts) async {
    try {
      if (phoneContacts.isEmpty) {
        debugPrint('⚠️ No contacts to sync');
        return phoneContacts;
      }

      final token = await _authService.getToken();
      if (token == null) {
        debugPrint('⚠️ No auth token, skipping sync');
        return phoneContacts;
      }

      debugPrint('🔄 Syncing ${phoneContacts.length} contacts with backend...');

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
        final syncedContacts = contacts.map((c) => ContactModel.fromJson(c)).toList();
        
        debugPrint('✅ Synced ${syncedContacts.length} contacts with backend');
        return syncedContacts.isNotEmpty ? syncedContacts : phoneContacts;
      } else {
        debugPrint('⚠️ Backend sync failed: ${response.statusCode}');
        return phoneContacts;
      }
    } catch (e) {
      debugPrint('❌ Error syncing contacts: $e');
      return phoneContacts;
    }
  }

  /// Get contacts from backend (with fallback to phone contacts)
  Future<List<ContactModel>> getContacts() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        debugPrint('⚠️ No token, getting phone contacts');
        return await getPhoneContacts();
      }

      debugPrint('🔍 Fetching contacts from backend...');

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
        final backendContacts = contacts.map((c) => ContactModel.fromJson(c)).toList();
        
        debugPrint('✅ Got ${backendContacts.length} contacts from backend');
        return backendContacts;
      }
      
      debugPrint('⚠️ Backend fetch failed, falling back to phone contacts');
      return await getPhoneContacts();
    } catch (e) {
      debugPrint('❌ Error getting contacts: $e');
      return await getPhoneContacts();
    }
  }

  /// Search contacts locally
  List<ContactModel> searchContactsLocally(List<ContactModel> contacts, String query) {
    if (query.trim().isEmpty) return contacts;
    
    final lowerQuery = query.toLowerCase().trim();
    
    return contacts.where((contact) {
      final nameLower = contact.name.toLowerCase();
      final phoneLower = contact.phone?.toLowerCase() ?? '';
      final emailLower = contact.email?.toLowerCase() ?? '';
      
      return nameLower.contains(lowerQuery) || 
             phoneLower.contains(lowerQuery) ||
             emailLower.contains(lowerQuery);
    }).toList();
  }
}
