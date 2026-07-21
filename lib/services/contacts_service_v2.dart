import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_service.dart';

/// ContactsServiceV2 — Gestion complète des contacts
///
/// Routes backend utilisées :
///   GET  /api/contacts              → liste mes contacts
///   POST /api/contacts/sync         → synchro carnet (mobile)
///   POST /api/contacts/add          → ajouter un contact unique
///   DELETE /api/contacts/:phone     → supprimer un contact
///   GET  /api/contacts/check/:phone → vérifier si un numéro est sur OmniSMS
class ContactsServiceV2 {
  final AuthService _authService = AuthService();

  // ── Normalisation numéro de téléphone ────────────────────────
  String normalizePhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^0+'), '');
    if (!cleaned.startsWith('+') && cleaned.length >= 8) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  // ── Contacts depuis l'appareil (mobile uniquement) ───────────
  /// Sur web : toujours retourne []
  Future<List<ContactModel>> getPhoneContacts() async {
    if (kIsWeb) {
      debugPrint('⚠️ getPhoneContacts: not available on web');
      return [];
    }
    debugPrint('⚠️ getPhoneContacts: mobile stub');
    return [];
  }

  // ── Synchroniser les contacts avec le backend ─────────────────
  /// Envoie la liste des contacts téléphoniques au backend.
  /// Le backend compare avec les utilisateurs OmniSMS et retourne
  /// uniquement ceux qui ont un compte.
  Future<List<ContactModel>> syncContacts(
      List<ContactModel> phoneContacts) async {
    try {
      if (phoneContacts.isEmpty) return phoneContacts;

      final token = await _authService.getToken();
      if (token == null) {
        debugPrint('⚠️ syncContacts: no auth token');
        return phoneContacts;
      }

      debugPrint(
          '🔄 Syncing ${phoneContacts.length} contacts with backend...');

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}/sync'),
            headers: {
              ...ApiConfig.headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'contacts': phoneContacts
                  .map((c) => {
                        'name': c.name,
                        'phone': c.phone ?? '',
                      })
                  .toList(),
              'country': 'BF',
            }),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List rawContacts = data['contacts'] ?? [];
        final synced = rawContacts
            .map((c) => ContactModel.fromJson(c as Map<String, dynamic>))
            .toList();
        debugPrint('✅ Synced: ${synced.length} OmniSMS users found');
        return synced.isNotEmpty ? synced : phoneContacts;
      } else {
        debugPrint('⚠️ syncContacts failed: ${response.statusCode}');
        return phoneContacts;
      }
    } on TimeoutException {
      debugPrint('⚠️ syncContacts timeout');
      return phoneContacts;
    } catch (e) {
      debugPrint('❌ syncContacts error: $e');
      return phoneContacts;
    }
  }

  // ── Récupérer mes contacts depuis le backend ──────────────────
  Future<List<ContactModel>> getContacts() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        debugPrint('⚠️ getContacts: no token');
        return [];
      }

      debugPrint('🔍 Fetching contacts from backend...');

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}'),
            headers: {
              ...ApiConfig.headers,
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List rawContacts = data['contacts'] ?? [];
        final contacts = rawContacts
            .map((c) => ContactModel.fromJson(c as Map<String, dynamic>))
            .toList();
        debugPrint('✅ Got ${contacts.length} contacts from backend');
        return contacts;
      } else if (response.statusCode == 401) {
        debugPrint('⚠️ getContacts: 401 Unauthorized');
        return [];
      } else if (response.statusCode == 503) {
        debugPrint('⚠️ getContacts: Firestore unavailable');
        return [];
      }

      debugPrint('⚠️ getContacts: ${response.statusCode}');
      return [];
    } on TimeoutException {
      debugPrint('⚠️ getContacts: timeout');
      return [];
    } catch (e) {
      debugPrint('❌ getContacts error: $e');
      return [];
    }
  }

  // ── Ajouter un contact unique ─────────────────────────────────
  /// POST /api/contacts/add { name, phone, country }
  /// Retourne { success, added, contact, message, error? }
  Future<Map<String, dynamic>> addContact({
    required String name,
    required String phone,
    String country = 'BF',
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {
          'success': false,
          'error': 'Vous devez être connecté pour ajouter un contact.',
        };
      }

      // Normaliser le numéro avant envoi
      final normalizedPhone = normalizePhoneNumber(phone);
      debugPrint(
          '➕ Adding contact: name=$name, phone=$normalizedPhone');

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}/add'),
            headers: {
              ...ApiConfig.headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name': name.trim(),
              'phone': normalizedPhone,
              'country': country,
            }),
          )
          .timeout(ApiConfig.requestTimeout);

      debugPrint('[AddContact] Response ${response.statusCode}: ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Construire le ContactModel depuis la réponse
        ContactModel? contact;
        if (data['contact'] != null) {
          final c = data['contact'] as Map<String, dynamic>;
          contact = ContactModel(
            id: c['phone'] ?? normalizedPhone,
            name: c['name'] ?? name,
            phone: c['phone'] ?? normalizedPhone,
          );
        } else {
          contact = ContactModel(
            id: normalizedPhone,
            name: name.trim(),
            phone: normalizedPhone,
          );
        }
        return {
          'success': true,
          'added': data['added'] ?? true,
          'contact': contact,
          'message': data['message'] ?? 'Contact ajouté.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'error': data['error'] ??
              data['fields']?.first?['msg'] ??
              'Données invalides.',
        };
      } else if (response.statusCode == 503) {
        return {
          'success': false,
          'error': 'Service temporairement indisponible. Réessayez.',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Erreur ${response.statusCode}',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Délai d\'attente dépassé. Réessayez.',
      };
    } catch (e) {
      debugPrint('❌ addContact error: $e');
      return {
        'success': false,
        'error': 'Erreur réseau : $e',
      };
    }
  }

  // ── Supprimer un contact ──────────────────────────────────────
  Future<Map<String, dynamic>> deleteContact(String phone) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {'success': false, 'error': 'Non authentifié'};
      }

      final normalized = normalizePhoneNumber(phone);
      final response = await http
          .delete(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}/${Uri.encodeComponent(normalized)}'),
            headers: {
              ...ApiConfig.headers,
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Erreur ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }

  // ── Vérifier si un numéro est sur OmniSMS ────────────────────
  Future<Map<String, dynamic>> checkPhone(String phone) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return {'registered': false};

      final normalized = normalizePhoneNumber(phone);
      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}/check/${Uri.encodeComponent(normalized)}'),
            headers: {
              ...ApiConfig.headers,
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'registered': data['registered'] ?? false,
          'user': data['user'],
        };
      }
      return {'registered': false};
    } catch (e) {
      return {'registered': false};
    }
  }

  // ── Recherche locale ──────────────────────────────────────────
  List<ContactModel> searchContactsLocally(
      List<ContactModel> contacts, String query) {
    if (query.trim().isEmpty) return contacts;

    final lowerQuery = query.toLowerCase().trim();
    return contacts.where((c) {
      return c.name.toLowerCase().contains(lowerQuery) ||
          (c.phone?.toLowerCase().contains(lowerQuery) ?? false) ||
          (c.email?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}
