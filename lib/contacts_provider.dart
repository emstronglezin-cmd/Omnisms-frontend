import 'package:flutter/material.dart';
import 'services/api_service.dart';

class ContactsProvider extends ChangeNotifier {
  final List<String> _contacts = [];
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  bool _hasTriedFetch = false;

  List<String> get contacts => List.unmodifiable(_contacts);
  bool get isLoading => _isLoading;
  String? get error => _error;

  ContactsProvider() {
    // Initialiser avec des contacts par défaut
    _initializeDefaultContacts();
  }

  void _initializeDefaultContacts() {
    _contacts.addAll([
      'Service Client',
      'Support',
      'Assistance',
    ]);
  }

  /// Récupère la liste des contacts depuis l'API
  Future<void> fetchContacts() async {
    _setLoading(true);
    _clearError();
    _hasTriedFetch = true;

    try {
      final contacts = await _apiService.getContacts();
      if (contacts.isNotEmpty) {
        _contacts.clear();
        _contacts.addAll(contacts);
      }
      notifyListeners();
    } catch (e) {
      // Mode hors ligne : garder les contacts par défaut
      debugPrint('Erreur chargement contacts (mode hors ligne): $e');
      _setError('Mode hors ligne - Contacts par défaut affichés');
      // Ne pas effacer les contacts existants
    }

    _setLoading(false);
  }

  /// Ajoute un nouveau contact
  void addContact(String contactName) {
    if (!_contacts.contains(contactName) && contactName.trim().isNotEmpty) {
      _contacts.add(contactName);
      notifyListeners();
    }
  }

  /// Supprime un contact
  void removeContact(String contactName) {
    _contacts.remove(contactName);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
