import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_contacts/flutter_contacts.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_service.dart';

class ContactsService {
  final AuthService _authService = AuthService();

  // Request contacts permission
  Future<bool> requestContactsPermission() async {
    return await FlutterContacts.requestPermission();
  }

  // Get phone contacts
  Future<List<ContactModel>> getPhoneContacts() async {
    try {
      final hasPermission = await requestContactsPermission();
      if (!hasPermission) {
        throw Exception('Permission denied');
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
      
      final contactList = <ContactModel>[];

      for (var contact in contacts) {
        if (contact.phones.isNotEmpty) {
          String? photoUrl;
          if (contact.photo != null) {
            photoUrl = 'data:image/png;base64,${contact.photo}';
          }

          contactList.add(
            ContactModel(
              id: contact.id,
              name: contact.displayName,
              phone: contact.phones.first.number,
              email: contact.emails.isNotEmpty 
                  ? contact.emails.first.address 
                  : null,
              photoUrl: photoUrl,
            ),
          );
        }
      }

      return contactList;
    } catch (e) {
      print('Error getting phone contacts: $e');
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
      print('Error syncing contacts: $e');
      return phoneContacts;
    }
  }

  // Get contacts from backend
  Future<List<ContactModel>> getContacts() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        // If not logged in, return phone contacts
        return await getPhoneContacts();
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
      
      // Fallback to phone contacts
      return await getPhoneContacts();
    } catch (e) {
      print('Error getting contacts: $e');
      // Fallback to phone contacts
      return await getPhoneContacts();
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
      print('Error searching contacts: $e');
      return [];
    }
  }
}
