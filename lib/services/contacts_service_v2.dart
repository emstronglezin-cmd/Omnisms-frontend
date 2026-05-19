import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_contacts/flutter_contacts.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'permissions_service.dart';

class ContactsServiceV2 {
  final AuthService _authService = AuthService();
  final PermissionsService _permissionsService = PermissionsService();

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
  Future<List<ContactModel>> getPhoneContacts() async {
    try {
      debugPrint('🔍 Starting contacts fetch...');
      
      // Check permission status
      final permissionStatus = await _permissionsService.getContactsPermissionStatus();
      
      if (permissionStatus == PermissionStatusExtended.denied ||
          permissionStatus == PermissionStatusExtended.permanentlyDenied ||
          permissionStatus == PermissionStatusExtended.restricted) {
        debugPrint('❌ Permission not granted: $permissionStatus');
        return [];
      }

      debugPrint('✅ Permission granted, loading contacts...');
      
      // Fetch contacts from device
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false, // Faster loading
        withThumbnail: false,
        withAccounts: false,
        withGroups: false,
      );
      
      debugPrint('📱 Found ${contacts.length} contacts on device');
      
      if (contacts.isEmpty) {
        debugPrint('⚠️ No contacts found on device');
        return [];
      }

      final contactList = <ContactModel>[];
      final seenPhones = <String>{};

      for (var contact in contacts) {
        // Skip contacts without phone numbers
        if (contact.phones.isEmpty) continue;

        // Process all phone numbers for this contact
        for (var phone in contact.phones) {
          try {
            // Normalize phone number
            final normalizedPhone = normalizePhoneNumber(phone.number);
            
            // Skip duplicates
            if (seenPhones.contains(normalizedPhone)) continue;
            seenPhones.add(normalizedPhone);
            
            // Skip too short numbers
            if (normalizedPhone.replaceAll('+', '').length < 8) continue;

            // Get display name
            final displayName = contact.displayName.trim().isNotEmpty
                ? contact.displayName
                : normalizedPhone;

            // Create contact model
            contactList.add(
              ContactModel(
                id: '${contact.id}_${phone.normalizedNumber}',
                name: displayName,
                phone: normalizedPhone,
                email: contact.emails.isNotEmpty 
                    ? contact.emails.first.address 
                    : null,
                photoUrl: null,
              ),
            );
          } catch (e) {
            debugPrint('⚠️ Error processing phone number: $e');
          }
        }
      }

      // Sort contacts alphabetically
      contactList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      debugPrint('✅ Processed ${contactList.length} valid contacts');
      return contactList;
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting phone contacts: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
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
