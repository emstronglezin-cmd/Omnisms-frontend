import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/contacts_service.dart';

class ContactsProvider with ChangeNotifier {
  final ContactsService _contactsService = ContactsService();

  List<ContactModel> _contacts = [];
  List<ContactModel> _filteredContacts = [];
  bool _isLoading = false;
  String? _error;
  bool _hasPermission = false;

  List<ContactModel> get contacts => _filteredContacts.isEmpty ? _contacts : _filteredContacts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPermission => _hasPermission;

  Future<void> loadContacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get phone contacts
      final phoneContacts = await _contactsService.getPhoneContacts();
      _hasPermission = phoneContacts.isNotEmpty;
      
      // Sync with backend
      _contacts = await _contactsService.syncContacts(phoneContacts);
      _filteredContacts = [];
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des contacts: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    _hasPermission = await _contactsService.requestContactsPermission();
    notifyListeners();
    
    if (_hasPermission) {
      await loadContacts();
    }
  }

  void searchContacts(String query) {
    if (query.isEmpty) {
      _filteredContacts = [];
    } else {
      _filteredContacts = _contacts.where((contact) {
        final nameLower = contact.name.toLowerCase();
        final phoneLower = contact.phone?.toLowerCase() ?? '';
        final queryLower = query.toLowerCase();
        return nameLower.contains(queryLower) || phoneLower.contains(queryLower);
      }).toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _filteredContacts = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
