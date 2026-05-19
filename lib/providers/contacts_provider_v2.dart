import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/contacts_service_v2.dart';
import '../services/permissions_service.dart';

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
  final PermissionsService _permissionsService = PermissionsService();

  List<ContactModel> _allContacts = [];
  List<ContactModel> _filteredContacts = [];
  
  ContactsLoadingState _loadingState = ContactsLoadingState.initial;
  String? _errorMessage;
  String _searchQuery = '';
  
  PermissionStatusExtended _permissionStatus = PermissionStatusExtended.denied;

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

  /// Check current permission status
  Future<void> checkPermissionStatus() async {
    try {
      _permissionStatus = await _permissionsService.getContactsPermissionStatus();
      
      debugPrint('📋 Permission status: $_permissionStatus');
      
      if (_permissionStatus == PermissionStatusExtended.permanentlyDenied) {
        _loadingState = ContactsLoadingState.permissionPermanentlyDenied;
      } else if (_permissionStatus == PermissionStatusExtended.denied ||
                 _permissionStatus == PermissionStatusExtended.restricted) {
        _loadingState = ContactsLoadingState.permissionDenied;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error checking permission: $e');
    }
  }

  /// Request contacts permission
  Future<bool> requestPermission() async {
    try {
      debugPrint('📲 Requesting contacts permission...');
      
      _loadingState = ContactsLoadingState.loading;
      notifyListeners();

      _permissionStatus = await _permissionsService.requestContactsPermission();
      
      debugPrint('📋 Permission result: $_permissionStatus');

      if (_permissionStatus == PermissionStatusExtended.granted ||
          _permissionStatus == PermissionStatusExtended.limited) {
        debugPrint('✅ Permission granted, loading contacts...');
        await loadContacts();
        return true;
      } else if (_permissionStatus == PermissionStatusExtended.permanentlyDenied) {
        _loadingState = ContactsLoadingState.permissionPermanentlyDenied;
        _errorMessage = 'Permission refusée. Veuillez l\'activer dans les paramètres.';
        notifyListeners();
        return false;
      } else {
        _loadingState = ContactsLoadingState.permissionDenied;
        _errorMessage = 'Permission requise pour accéder aux contacts';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting permission: $e');
      _loadingState = ContactsLoadingState.error;
      _errorMessage = 'Erreur lors de la demande de permission';
      notifyListeners();
      return false;
    }
  }

  /// Load all contacts
  Future<void> loadContacts() async {
    try {
      debugPrint('📱 Loading contacts...');
      
      _loadingState = ContactsLoadingState.loading;
      _errorMessage = null;
      notifyListeners();

      // Get phone contacts
      final phoneContacts = await _contactsService.getPhoneContacts();
      
      if (phoneContacts.isEmpty) {
        debugPrint('⚠️ No contacts loaded');
        _loadingState = ContactsLoadingState.loaded;
        _allContacts = [];
        _filteredContacts = [];
        notifyListeners();
        return;
      }

      debugPrint('✅ Loaded ${phoneContacts.length} contacts from phone');
      
      // Update UI immediately with phone contacts
      _allContacts = phoneContacts;
      _filteredContacts = [];
      _loadingState = ContactsLoadingState.loaded;
      notifyListeners();

      // Sync with backend in background (don't wait)
      _syncContactsInBackground(phoneContacts);
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading contacts: $e');
      debugPrint('Stack trace: $stackTrace');
      
      _loadingState = ContactsLoadingState.error;
      _errorMessage = 'Erreur lors du chargement des contacts: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Sync contacts with backend in background
  Future<void> _syncContactsInBackground(List<ContactModel> phoneContacts) async {
    try {
      debugPrint('🔄 Syncing contacts with backend...');
      
      final syncedContacts = await _contactsService.syncContacts(phoneContacts);
      
      if (syncedContacts.isNotEmpty && syncedContacts != phoneContacts) {
        debugPrint('✅ Backend sync complete, updating UI');
        _allContacts = syncedContacts;
        
        // Re-apply search filter if active
        if (_searchQuery.isNotEmpty) {
          _applySearchFilter();
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Background sync error: $e');
      // Don't update UI on background sync errors
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

  /// Open app settings
  Future<void> openSettings() async {
    await _permissionsService.openAppSettings();
  }
}
