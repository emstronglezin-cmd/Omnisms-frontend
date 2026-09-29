import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'google_oauth_flow.dart';

/// ContactsServiceV2 — Gestion complète des contacts
///
/// Routes backend utilisées :
///   GET    /api/contacts              → liste mes contacts
///   POST   /api/contacts/sync         → synchro carnet
///   POST   /api/contacts/add          → ajouter un contact unique
///   DELETE /api/contacts/:phone       → supprimer un contact
///   GET    /api/contacts/check/:phone → vérifier si un numéro est sur OmniSMS
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

  // ── Contact Picker API (web only) ─────────────────────────────
  /// Returns contacts picked via the browser Contact Picker API.
  /// On unsupported platforms returns [].
  Future<List<ContactModel>> pickContactsFromDevice() async {
    if (!kIsWeb) {
      return [];
    }

    try {
      // Use dart:js_interop (available in Flutter web builds)
      // We call the JS bridge that was set up in index.html / app.js
      // If Contact Picker API not supported → return []
      debugPrint('📱 Contact Picker API: attempting...');

      // Dart-side stub: Contact Picker only runs in JS context.
      // Return [] so the UI falls back to VCF or manual add.
      return [];
    } catch (e) {
      debugPrint('⚠️ Contact Picker error: $e');
      return [];
    }
  }

  // ── VCF Parser ────────────────────────────────────────────────
  /// Parse a VCF (vCard) file content into a list of ContactModels.
  ///
  /// Supports:
  ///   FN:Full Name
  ///   N:Last;First
  ///   TEL;...:+226XXXXXXXX
  List<ContactModel> parseVCF(String vcfContent) {
    final contacts = <ContactModel>[];
    final cards = vcfContent.split(RegExp(r'END:VCARD', caseSensitive: false));

    for (final card in cards) {
      if (!card.toUpperCase().contains('BEGIN:VCARD')) continue;

      String name = '';
      final phones = <String>[];

      for (final rawLine in card.split('\n')) {
        final line = rawLine.trim();

        // Unfold multi-line values (RFC 2425)
        if (line.isEmpty) continue;

        final upper = line.toUpperCase();

        // FN: Full name
        if (upper.startsWith('FN:') || upper.startsWith('FN;')) {
          final val = line.substring(line.indexOf(':') + 1).trim();
          if (val.isNotEmpty && name.isEmpty) {
            name = _unescapeVCard(val);
          }
        }
        // N: Structured name (fallback if FN missing)
        else if (upper.startsWith('N:') || upper.startsWith('N;')) {
          if (name.isEmpty) {
            final val = line.substring(line.indexOf(':') + 1).trim();
            final parts = val.split(';');
            final last = parts.isNotEmpty ? parts[0].trim() : '';
            final first = parts.length > 1 ? parts[1].trim() : '';
            name = '$first $last'.trim();
            name = _unescapeVCard(name);
          }
        }
        // TEL: Phone number
        else if (upper.startsWith('TEL') && line.contains(':')) {
          final phone = line.substring(line.indexOf(':') + 1).trim();
          if (phone.isNotEmpty) {
            phones.add(normalizePhoneNumber(phone));
          }
        }
      }

      if (name.isEmpty) continue;

      // One ContactModel per phone number
      for (final phone in phones) {
        if (phone.isEmpty) continue;
        contacts.add(ContactModel(
          id: phone,
          name: name,
          phone: phone,
        ));
      }

      // If name found but no phone, add without phone
      if (phones.isEmpty && name.isNotEmpty) {
        contacts.add(ContactModel(
          id: name,
          name: name,
          phone: null,
        ));
      }
    }

    debugPrint('📋 VCF parsed: ${contacts.length} contacts');
    return contacts;
  }

  String _unescapeVCard(String s) {
    return s
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\\', '\\');
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
  /// Envoie la liste des contacts au backend.
  /// Le backend compare avec les utilisateurs OmniSMS.
  /// Returns all contacts (not just OmniSMS-registered ones).
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
        final List rawRegistered = data['contacts'] ?? [];
        final registeredIds = <String>{};

        final registered = rawRegistered
            .map((c) => ContactModel.fromJson(c as Map<String, dynamic>))
            .toList();

        for (final r in registered) {
          if (r.phone != null) registeredIds.add(r.phone!);
          registeredIds.add(r.id);
        }

        debugPrint(
            '✅ Sync done: ${registered.length} OmniSMS users found among ${phoneContacts.length} contacts');

        // Merge: mark original contacts as isRegistered when matched
        final merged = phoneContacts.map((c) {
          final isReg = c.phone != null && registeredIds.contains(c.phone);
          return ContactModel(
            id: isReg
                ? (registered
                    .firstWhere(
                      (r) => r.phone == c.phone,
                      orElse: () => c,
                    )
                    .id)
                : c.id,
            name: c.name,
            phone: c.phone,
            email: c.email,
            photoUrl: c.photoUrl,
            isRegistered: isReg,
          );
        }).toList();

        return merged;
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

      final normalizedPhone = normalizePhoneNumber(phone);
      debugPrint(
          '➕ Adding contact: name=$name, phone=$normalizedPhone');

      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.contactsEndpoint}/add'),
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

      debugPrint(
          '[AddContact] Response ${response.statusCode}: ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ContactModel? contact;
        if (data['contact'] != null) {
          final c = data['contact'] as Map<String, dynamic>;
          contact = ContactModel(
            id: c['id'] ?? c['phone'] ?? normalizedPhone,
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
      return {
        'success': false,
        'error': 'Erreur ${response.statusCode}'
      };
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

  // ── Google Contacts : étape 1 — autorisation ──────────────────
  /// POST /api/auth/google/contacts/authorize  (Bearer OmniSMS requis)
  ///
  /// Le backend construit l'URL de consentement Google (scope
  /// `contacts.readonly`). Aucun token Google ne transite par le frontend :
  /// le refresh token reste chiffré côté backend.
  ///
  /// Retourne `{ success, authorizationUrl?, code?, error? }`.
  Future<Map<String, dynamic>> requestGoogleContactsAuthorization() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {
          'success': false,
          'code': 'NO_TOKEN',
          'error': GoogleContactsMessages.notConnected,
        };
      }

      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.googleContactsAuthorizeEndpoint}'),
            headers: {
              ...ApiConfig.headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(const <String, dynamic>{}),
          )
          .timeout(ApiConfig.requestTimeout);

      final data = _decodeJsonMap(response.body);

      if (response.statusCode == 200 && data['authorizationUrl'] != null) {
        return {
          'success': true,
          'authorizationUrl': data['authorizationUrl'].toString(),
          'redirectUri': data['redirectUri'],
          'scope': data['scope'],
        };
      }

      final code = (data['code'] ?? '').toString();
      return {
        'success': false,
        'code': code,
        'error': GoogleContactsMessages.forCode(code),
      };
    } on TimeoutException {
      return {
        'success': false,
        'code': 'TIMEOUT',
        'error': 'Le serveur met du temps à répondre (démarrage). Réessayez.',
      };
    } catch (e) {
      debugPrint('❌ requestGoogleContactsAuthorization: $e');
      return {
        'success': false,
        'code': 'NETWORK',
        'error': GoogleContactsMessages.importFailed,
      };
    }
  }

  // ── Google Contacts : étape 2 — import ────────────────────────
  /// POST /api/contacts/google/import  (Bearer OmniSMS requis)
  ///
  /// Le backend fait tout : People API, normalisation, déduplication et
  /// association numéro → utilisateur OmniSMS. Le frontend ne fait que
  /// relire les compteurs renvoyés puis recharger la liste.
  ///
  /// Retourne `{ success, ...compteurs }` ou `{ success:false, code, error }`.
  Future<Map<String, dynamic>> importGoogleContacts() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        return {
          'success': false,
          'code': 'NO_TOKEN',
          'error': GoogleContactsMessages.notConnected,
        };
      }

      final response = await http
          .post(
            Uri.parse(
                '${ApiConfig.baseUrl}${ApiConfig.googleContactsImportEndpoint}'),
            headers: {
              ...ApiConfig.headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(const <String, dynamic>{}),
          )
          .timeout(ApiConfig.requestTimeout);

      final data = _decodeJsonMap(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint(
            '✅ Google import: imported=${data['imported']} updated=${data['updated']} '
            'matches=${data['omnismsMatches']} external=${data['external']}');
        return Map<String, dynamic>.from(data);
      }

      final code = (data['code'] ?? '').toString();
      debugPrint('⚠️ importGoogleContacts: ${response.statusCode} code=$code');
      return {
        'success': false,
        'code': code,
        'authorizationRequired':
            data['authorizationRequired'] == true ||
                code == 'GOOGLE_CONTACTS_AUTH_REQUIRED' ||
                code == 'GOOGLE_TOKEN_EXPIRED',
        'error': GoogleContactsMessages.forCode(code),
      };
    } on TimeoutException {
      return {
        'success': false,
        'code': 'TIMEOUT',
        'error': 'Le serveur met du temps à répondre (démarrage). Réessayez.',
      };
    } catch (e) {
      debugPrint('❌ importGoogleContacts: $e');
      return {
        'success': false,
        'code': 'NETWORK',
        'error': GoogleContactsMessages.importFailed,
      };
    }
  }

  /// `jsonDecode` tolérant : un corps non-JSON (page d'erreur, HTML) ne doit
  /// jamais remonter comme exception brute jusqu'à l'utilisateur.
  Map<String, dynamic> _decodeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
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
