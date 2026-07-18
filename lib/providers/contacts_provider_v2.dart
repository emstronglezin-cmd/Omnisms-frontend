import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/contacts_service_v2.dart';

/// Permission status — stub for web compatibility (mobile-only on device)
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

class ContactsProviderV2 with ChangeNotifier {
  final ContactsServiceV2 _contactsService = ContactsServiceV2();

  List<ContactModel> _allContacts = [];
  List<ContactModel> _filteredContacts = [];

  ContactsLoadingState _loadingState = ContactsLoadingState.initial;
  String? _errorMessage;
  String _searchQuery = '';

  // On web, permission is always granted (no device contacts anyway)
  final PermissionStatusExtended _permissionStatus = PermissionStatusExtended.granted;

  // Getters
  List<ContactModel> get contacts =>
      _searchQuery.isEmpty ? _allContacts : _filteredContacts;

  ContactsLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  PermissionStatusExtended get permissionStatus => _permissionStatus;

  bool get isLoading => _loadingState == ContactsLoadingState.loading;
  bool get hasError => _loadingState == ContactsLoadingState.error;
  bool get hasPermission =>
      _permissionStatus == PermissionStatusExtended.granted ||
      _permissionStatus == PermissionStatusExtended.limited;
  bool get isPermissionPermanentlyDenied =>
      _permissionStatus == PermissionStatusExtended.permanentlyDenied;

  /// Check current permission status (web: always granted)
  Future<void> checkPermissionStatus() async {
    debugPrint('📋 Permission status (web stub): granted');
    notifyListeners();
  }

  /// Request contacts permission (web: no-op, always granted)
  Future<bool> requestPermission() async {
    debugPrint('📲 Permission request (web stub): granted');
    await loadContacts();
    return true;
  }

  /// Load all contacts
  Future<void> loadContacts() async {
    try {
      debugPrint('📱 Loading contacts...');

      _loadingState = ContactsLoadingState.loading;
      _errorMessage = null;
      notifyListeners();

      // Get contacts (from backend or phone on mobile)
      final contacts = await _contactsService.getContacts();

      debugPrint('✅ Loaded ${contacts.length} contacts');

      _allContacts = contacts;
      _filteredContacts = [];
      _loadingState = ContactsLoadingState.loaded;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading contacts: $e');
      debugPrint('Stack trace: $stackTrace');

      _loadingState = ContactsLoadingState.error;
      _errorMessage = 'Erreur lors du chargement des contacts: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Search contacts
  void searchContacts(String query) {
    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      _filteredContacts = [];
    } else {
      _applySearchFilter();
    }

    notifyListeners();
  }

  /// Apply search filter
  void _applySearchFilter() {
    _filteredContacts = _contactsService.searchContactsLocally(
      _allContacts,
      _searchQuery,
    );

    debugPrint('🔍 Search "$_searchQuery" found ${_filteredContacts.length} results');
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _filteredContacts = [];
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh contacts
  Future<void> refreshContacts() async {
    await loadContacts();
  }

  /// Open app settings (stub on web)
  Future<void> openSettings() async {
    debugPrint('⚠️ openSettings: not available on web');
  }
}
