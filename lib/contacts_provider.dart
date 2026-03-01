import 'package:flutter/material.dart';
import 'services/api_service.dart';

class ContactsProvider extends ChangeNotifier {
  final List<String> _contacts = [];
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;

  List<String> get contacts => List.unmodifiable(_contacts);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Récupère la liste des contacts depuis l'API
  Future<void> fetchContacts() async {
    _setLoading(true);
    _clearError();

    // Affiche d'abord les contacts en cache si disponibles
    final cached = await _apiService.getCachedContactsLocally();
    if (cached != null && cached.isNotEmpty) {
      _contacts.clear();
      _contacts.addAll(cached);
      notifyListeners();
    }

    try {
      final contacts = await _apiService.getContacts();
      _contacts.clear();
      _contacts.addAll(contacts);
      notifyListeners();
    } catch (e) {
      _setError('Erreur lors du chargement des contacts: $e');
    }

    _setLoading(false);
  }

  /// Ajoute un nouveau contact
  void addContact(String contactName) {
    if (!_contacts.contains(contactName)) {
      _contacts.add(contactName);
      notifyListeners();
      // Mise en cache locale afin de conserver la liste hors ligne
      _apiService.cacheContactsLocally(_contacts);
    }
  }

  /// Supprime un contact
  void removeContact(String contactName) {
    _contacts.remove(contactName);
    notifyListeners();
    // Mettre à jour le cache local
    _apiService.cacheContactsLocally(_contacts);
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
