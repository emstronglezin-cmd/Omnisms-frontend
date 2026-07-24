import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/contacts_service_v2.dart';

/// Permission status — stub pour compatibilité web
/// Sur mobile, flutter_contacts gère les permissions réelles.
enum PermissionStatusExtended {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}

enum ContactsLoadingState {
  initial,
  loading,
  loaded,
  error,
  permissionDenied,
  permissionPermanentlyDenied,
}

/// ContactsProviderV2 — Gestion des contacts avec support web/mobile
///
/// Fonctionnalités :
///   - loadContacts()        → charge depuis le backend
///   - addContact()          → ajoute un contact via backend
///   - syncPhoneContacts()   → synchronise le carnet (mobile)
///   - syncVCFContacts()     → synchronise à partir d'un fichier VCF
///   - searchContacts()      → recherche locale
///   - checkPhone()          → vérifie si un numéro est sur OmniSMS
///
/// After sync: ALL contacts are shown (not just OmniSMS-registered).
/// Registered contacts are flagged with isRegistered = true.
class ContactsProviderV2 with ChangeNotifier {
  final ContactsServiceV2 _contactsService = ContactsServiceV2();

  List<ContactModel> _allContacts = [];
  List<ContactModel> _filteredContacts = [];

  ContactsLoadingState _loadingState = ContactsLoadingState.initial;
  String? _errorMessage;
  String _searchQuery = '';
  bool _isAddingContact = false;

  // Callback to create conversations for registered contacts
  // Set externally by the app (e.g., from MessagingProvider)
  Function(List<ContactModel> registeredContacts)? onSyncedRegisteredContacts;

  // Sur web, la permission est toujours accordée (pas de contacts appareil)
  PermissionStatusExtended _permissionStatus =
      kIsWeb ? PermissionStatusExtended.granted : PermissionStatusExtended.denied;

  // ── Getters ──────────────────────────────────────────────────
  List<ContactModel> get contacts =>
      _searchQuery.isEmpty ? _allContacts : _filteredContacts;

  ContactsLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  PermissionStatusExtended get permissionStatus => _permissionStatus;
  bool get isAddingContact => _isAddingContact;

  bool get isLoading => _loadingState == ContactsLoadingState.loading;
  bool get hasError => _loadingState == ContactsLoadingState.error;
  bool get hasPermission =>
      _permissionStatus == PermissionStatusExtended.granted ||
      _permissionStatus == PermissionStatusExtended.limited;
  bool get isPermissionPermanentlyDenied =>
      _permissionStatus == PermissionStatusExtended.permanentlyDenied;

  // ── Vérifier la permission ───────────────────────────────────
  Future<void> checkPermissionStatus() async {
    if (kIsWeb) {
      _permissionStatus = PermissionStatusExtended.granted;
      debugPrint('📋 Permission (web): granted');
      notifyListeners();
      return;
    }
    _permissionStatus = PermissionStatusExtended.granted;
    notifyListeners();
  }

  // ── Demander la permission ────────────────────────────────────
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      _permissionStatus = PermissionStatusExtended.granted;
      notifyListeners();
      await loadContacts();
      return true;
    }
    _permissionStatus = PermissionStatusExtended.granted;
    notifyListeners();
    await loadContacts();
    return true;
  }

  // ── Charger les contacts depuis le backend ────────────────────
  Future<void> loadContacts() async {
    try {
      debugPrint('📱 Loading contacts from backend...');

      _loadingState = ContactsLoadingState.loading;
      _errorMessage = null;
      notifyListeners();

      final contacts = await _contactsService.getContacts();

      debugPrint('✅ Loaded ${contacts.length} contacts');

      _allContacts = contacts;
      _filteredContacts = [];
      _loadingState = ContactsLoadingState.loaded;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ loadContacts error: $e');
      debugPrint('Stack: $stackTrace');

      _loadingState = ContactsLoadingState.error;
      _errorMessage = 'Erreur chargement contacts : ${e.toString()}';
      notifyListeners();
    }
  }

  // ── Ajouter un contact via le backend ─────────────────────────
  /// Retourne { success, message?, error? }
  Future<Map<String, dynamic>> addContact({
    required String name,
    required String phone,
    String country = 'BF',
  }) async {
    _isAddingContact = true;
    notifyListeners();

    try {
      final result = await _contactsService.addContact(
        name: name,
        phone: phone,
        country: country,
      );

      if (result['success'] == true) {
        final contact = result['contact'] as ContactModel?;
        if (contact != null) {
          // Éviter les doublons
          final alreadyExists = _allContacts.any(
            (c) => c.phone == contact.phone || c.id == contact.id,
          );
          if (!alreadyExists) {
            _allContacts = [contact, ..._allContacts];
          }
        }
        _loadingState = ContactsLoadingState.loaded;
      }

      _isAddingContact = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isAddingContact = false;
      notifyListeners();
      return {'success': false, 'error': 'Erreur : $e'};
    }
  }

  // ── Synchroniser un ensemble de contacts locaux ───────────────
  /// Accepts a list of ContactModels (from VCF or device picker).
  /// Sends to backend POST /api/contacts/sync.
  /// Shows ALL contacts (not just registered ones).
  /// Registered contacts get isRegistered = true.
  Future<void> syncContacts(List<ContactModel> localContacts) async {
    if (localContacts.isEmpty) {
      await loadContacts();
      return;
    }

    try {
      _loadingState = ContactsLoadingState.loading;
      notifyListeners();

      final merged =
          await _contactsService.syncContacts(localContacts);

      // Merge with existing contacts (avoid duplicates by phone)
      final existingPhones = <String>{
        for (final c in _allContacts)
          if (c.phone != null) c.phone!
      };

      final newContacts = merged
          .where((c) => c.phone == null || !existingPhones.contains(c.phone))
          .toList();

      _allContacts = [...merged, ...newContacts];

      // Deduplicate by phone
      final seen = <String>{};
      _allContacts = _allContacts.where((c) {
        final key = c.phone ?? c.id;
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      }).toList();

      _loadingState = ContactsLoadingState.loaded;
      notifyListeners();

      // Notify registered contacts for conversation creation
      final registered =
          _allContacts.where((c) => c.isRegistered).toList();
      if (registered.isNotEmpty && onSyncedRegisteredContacts != null) {
        onSyncedRegisteredContacts!(registered);
      }

      debugPrint(
          '✅ Sync complete: ${_allContacts.length} total, ${registered.length} OmniSMS');
    } catch (e) {
      _loadingState = ContactsLoadingState.error;
      _errorMessage = 'Erreur synchronisation : $e';
      notifyListeners();
    }
  }

  // ── Synchroniser le carnet d'adresses (mobile) ───────────────
  Future<void> syncPhoneContacts() async {
    try {
      _loadingState = ContactsLoadingState.loading;
      notifyListeners();

      final phoneContacts = await _contactsService.getPhoneContacts();
      if (phoneContacts.isEmpty) {
        // Sur web ou si pas de contacts : charger depuis le backend directement
        await loadContacts();
        return;
      }

      await syncContacts(phoneContacts);
    } catch (e) {
      _loadingState = ContactsLoadingState.error;
      _errorMessage = 'Erreur synchronisation : $e';
      notifyListeners();
    }
  }

  // ── Synchroniser depuis un fichier VCF ────────────────────────
  /// Parse the VCF content and sync with backend.
  Future<void> syncVCFContacts(String vcfContent) async {
    final parsed = _contactsService.parseVCF(vcfContent);
    debugPrint('📋 VCF: ${parsed.length} contacts parsed');
    await syncContacts(parsed);
  }

  // ── Supprimer un contact ──────────────────────────────────────
  Future<Map<String, dynamic>> deleteContact(String phone) async {
    try {
      final result = await _contactsService.deleteContact(phone);
      if (result['success'] == true) {
        _allContacts.removeWhere((c) => c.phone == phone);
        notifyListeners();
      }
      return result;
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }

  // ── Vérifier si un numéro est sur OmniSMS ────────────────────
  Future<Map<String, dynamic>> checkPhone(String phone) async {
    return _contactsService.checkPhone(phone);
  }

  // ── Recherche de contacts ─────────────────────────────────────
  void searchContacts(String query) {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      _filteredContacts = [];
    } else {
      _filteredContacts = _contactsService.searchContactsLocally(
        _allContacts,
        _searchQuery,
      );
      debugPrint(
          '🔍 Search "$_searchQuery": ${_filteredContacts.length} results');
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredContacts = [];
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshContacts() async {
    await loadContacts();
  }

  /// Ouvrir les paramètres de l'app (stub web)
  Future<void> openSettings() async {
    debugPrint('⚠️ openSettings: not available on web');
  }
}
