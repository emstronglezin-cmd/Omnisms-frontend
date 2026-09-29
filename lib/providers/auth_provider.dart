import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/google_oauth_flow.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _isGoogleSignInInProgress = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isGoogleSignInInProgress => _isGoogleSignInInProgress;

  /// Bloque les doubles clics sur le bouton Google.
  bool get isBusy => _isLoading || _isGoogleSignInInProgress;
  String? get error => _error;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();

    _isLoggedIn = await _authService.isLoggedIn();
    if (_isLoggedIn) {
      _currentUser = await _authService.getCurrentUser();
      // Jeton explicitement refusé par /api/auth/me → session expirée.
      // (Un backend endormi ou un timeout ne déconnecte pas l'utilisateur.)
      if (_currentUser == null && _authService.sessionExpired) {
        await _authService.logout();
        _isLoggedIn = false;
      }
    }

    // Écoute des deep links Google démarrée dès le lancement : indispensable
    // pour capter le lien initial quand l'app est relancée par Google.
    await GoogleOAuthFlow.instance.start();

    // Retour Google « à froid » : l'app a été relancée par le deep link
    // omnisms://auth/google/callback. On finalise la session sans redemander
    // de saisie à l'utilisateur.
    if (!_isLoggedIn) {
      final recovered = await _authService.recoverGoogleLoginIfPending();
      if (recovered['success'] == true) {
        _currentUser = recovered['user'];
        _isLoggedIn = true;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );

      if (result['success']) {
        _currentUser = result['user'];
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erreur lors de l\'inscription';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result['success']) {
        _currentUser = result['user'];
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erreur lors de la connexion';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Connexion Google — même cycle de vie que [login] (loading, erreur,
  /// utilisateur courant, notification de l'interface).
  ///
  /// Le flux lui-même (navigateur → Google → deep link → échange du code)
  /// est porté par [AuthService.loginWithGoogle].
  Future<bool> loginWithGoogle() async {
    // Anti double-clic : ignore toute nouvelle tentative pendant le flux.
    if (_isGoogleSignInInProgress) return false;

    // NB : _isLoading reste réservé au login email/mot de passe (le bouton
    // « Se connecter » affiche son spinner dessus). Le flux Google utilise son
    // propre drapeau pour ne pas faire spinner le mauvais bouton.
    _isGoogleSignInInProgress = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.loginWithGoogle();

      if (result['success'] == true) {
        _currentUser = result['user'];
        _isLoggedIn = true;
        _isGoogleSignInInProgress = false;
        notifyListeners();
        return true;
      }

      _error = result['message'] ?? 'Impossible de se connecter avec Google.';
      _isGoogleSignInInProgress = false;
      notifyListeners();
      return false;
    } catch (e) {
      // Message générique : jamais d'exception brute ni de détail OAuth.
      _error = 'Impossible de se connecter avec Google. Réessayez.';
      _isGoogleSignInInProgress = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.updateProfile(
        name: name,
        email: email,
        phone: phone,
        photoUrl: photoUrl,
      );

      if (result['success']) {
        // AuthService.updateProfile ne retourne pas de clé 'user' :
        // recharger le profil depuis /api/auth/me pour éviter un _currentUser null.
        final refreshed = await _authService.getCurrentUser();
        if (refreshed != null) {
          _currentUser = refreshed;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erreur lors de la mise à jour';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
