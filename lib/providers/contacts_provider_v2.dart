import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/contacts_service_v2.dart';
import '../services/google_oauth_flow.dart';

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

/// États du flux « Importer depuis Google ».
enum GoogleImportState {
  idle,

  /// « Connexion à Google… » (autorisation en cours)
  connecting,

  /// « Importation des contacts… » (appel backend)
  importing,

  /// « Contacts importés »
  success,

  /// « Autorisation Google refusée. »
  denied,

  /// « Impossible d'importer les contacts Google. »
  error,
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
  final AuthService _authService = AuthService();

  List<ContactModel> _allContacts = [];
  List<ContactModel> _filteredContacts = [];

  ContactsLoadingState _loadingState = ContactsLoadingState.initial;
  String? _errorMessage;
  String _searchQuery = '';
  bool _isAddingContact = false;

  // ── Import Google ────────────────────────────────────────────
  GoogleImportState _googleImportState = GoogleImportState.idle;
  String? _googleImportMessage;
  Map<String, dynamic> _googleImportSummary = const {};

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

  // ── Getters import Google ────────────────────────────────────
  GoogleImportState get googleImportState => _googleImportState;
  String? get googleImportMessage => _googleImportMessage;
  Map<String, dynamic> get googleImportSummary => _googleImportSummary;

  bool get isImportingFromGoogle =>
      _googleImportState == GoogleImportState.connecting ||
      _googleImportState == GoogleImportState.importing;

  bool get isGoogleImportDenied =>
      _googleImportState == GoogleImportState.denied;

  bool get hasGoogleImportError =>
      _googleImportState == GoogleImportState.error;

  /// Libellé affiché pendant/après le flux (« Connexion à Google… », etc.).
  String get googleImportLabel {
    if (_googleImportState == GoogleImportState.connecting) {
      return 'Connexion à Google…';
    }
    if (_googleImportState == GoogleImportState.importing) {
      return 'Importation des contacts…';
    }
    if (_googleImportState == GoogleImportState.idle) {
      return '';
    }
    if (_googleImportMessage != null && _googleImportMessage!.isNotEmpty) {
      return _googleImportMessage!;
    }
    if (_googleImportState == GoogleImportState.success) {
      return GoogleContactsMessages.success;
    }
    if (_googleImportState == GoogleImportState.denied) {
      return GoogleContactsMessages.denied;
    }
    return GoogleContactsMessages.importFailed;
  }

  /// Détail des compteurs renvoyés par le backend après un import réussi
  /// (ex : « 25 importés, 4 mis à jour, 12 sur OmniSMS »).
  String get googleImportDetail {
    if (_googleImportSummary.isEmpty) return '';
    return GoogleContactsMessages.summary(_googleImportSummary);
  }

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

  // ── Importer depuis Google ────────────────────────────────────
  /// Flux complet, tel que défini par le backend :
  ///   1. vérification de la session OmniSMS ;
  ///   2. POST /api/auth/google/contacts/authorize → URL de consentement ;
  ///   3. consentement Google dans le navigateur système ;
  ///   4. retour via le deep link omnisms://auth/google/contacts/callback ;
  ///   5. POST /api/contacts/google/import ;
  ///   6. rechargement de la liste depuis le backend.
  ///
  /// Le backend gère People API, la normalisation, la déduplication et
  /// l'association numéro → utilisateur OmniSMS : rien n'est refait ici.
  Future<Map<String, dynamic>> importFromGoogle() async {
    if (isImportingFromGoogle) {
      return {'success': false, 'error': 'Importation déjà en cours.'};
    }

    final flow = GoogleOAuthFlow.instance;

    try {
      // 1. Session OmniSMS
      final loggedIn = await _authService.isLoggedIn();
      if (!loggedIn) {
        return _failGoogleImport(
          GoogleContactsMessages.notConnected,
          'NO_TOKEN',
        );
      }

      // 2. Démarrer l'autorisation Google
      _setGoogleImportState(GoogleImportState.connecting);

      final authorization =
          await _contactsService.requestGoogleContactsAuthorization();
      if (authorization['success'] != true) {
        return _failGoogleImport(
          (authorization['error'] ?? GoogleContactsMessages.importFailed)
              .toString(),
          (authorization['code'] ?? '').toString(),
        );
      }

      // 3. Consentement dans le navigateur système
      flow.clearPending();
      await flow.start();

      final opened =
          await flow.openExternal(authorization['authorizationUrl'].toString());
      if (!opened) {
        return _failGoogleImport(
          GoogleContactsMessages.browserUnavailable,
          'BROWSER_UNAVAILABLE',
        );
      }

      // 4. Retour depuis Google
      final GoogleCallback callback;
      try {
        callback = await flow.waitFor(GoogleCallbackKind.contacts);
      } on TimeoutException {
        return _failGoogleImport(GoogleContactsMessages.timeout, 'TIMEOUT');
      } on GoogleFlowCancelledException {
        return _failGoogleImport(GoogleContactsMessages.denied, 'CANCELLED');
      }

      if (!callback.isSuccess) {
        return _failGoogleImport(
          GoogleContactsMessages.forCode(callback.error,
              fallback: GoogleContactsMessages.denied),
          callback.error ?? 'GOOGLE_OAUTH_DENIED',
        );
      }

      // 5. Import côté backend
      _setGoogleImportState(GoogleImportState.importing);

      final result = await _contactsService.importGoogleContacts();
      if (result['success'] != true) {
        return _failGoogleImport(
          (result['error'] ?? GoogleContactsMessages.importFailed).toString(),
          (result['code'] ?? '').toString(),
        );
      }

      // 6. Recharger la liste depuis le backend (aucune fusion locale :
      //    la déduplication est déjà faite côté serveur).
      await loadContacts();

      _googleImportState = GoogleImportState.success;
      _googleImportSummary = Map<String, dynamic>.from(result);
      _googleImportMessage = GoogleContactsMessages.success;
      notifyListeners();

      debugPrint(
          '✅ Google Contacts import terminé: ${GoogleContactsMessages.summary(result)}');
      return result;
    } catch (e) {
      debugPrint('❌ importFromGoogle: $e');
      return _failGoogleImport(GoogleContactsMessages.importFailed, 'ERROR');
    }
  }

  void _setGoogleImportState(GoogleImportState state) {
    _googleImportState = state;
    _googleImportMessage = null;
    notifyListeners();
  }

  Map<String, dynamic> _failGoogleImport(String message, String code) {
    _googleImportState = message == GoogleContactsMessages.denied
        ? GoogleImportState.denied
        : GoogleImportState.error;
    _googleImportMessage = message;
    _googleImportSummary = const {};
    notifyListeners();
    debugPrint('⚠️ Google Contacts import: $code → $message');
    return {'success': false, 'code': code, 'error': message};
  }

  /// Remet l'état Google à zéro (après affichage du message à l'utilisateur).
  void resetGoogleImport() {
    if (_googleImportState == GoogleImportState.idle) return;
    _googleImportState = GoogleImportState.idle;
    _googleImportMessage = null;
    _googleImportSummary = const {};
    notifyListeners();
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
