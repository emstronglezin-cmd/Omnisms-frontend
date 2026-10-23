import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/google_oauth_flow.dart';
import '../services/otp_service.dart';
import '../services/realtime_service.dart';

class AuthProvider with ChangeNotifier {
  /// Injectables pour les tests (clients HTTP simulés).
  AuthProvider({AuthService? authService, OtpService? otpService})
      : _authService = authService ?? AuthService(),
        _otpService = otpService ?? OtpService() {
    _checkLoginStatus();
  }

  final AuthService _authService;
  final OtpService _otpService;

  UserModel? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _isGoogleSignInInProgress = false;
  String? _error;

  /// Vérification de numéro exigée par le serveur, en cours.
  ///
  /// Non nul ⇒ la session est FERMÉE : aucun écran principal n'est accessible
  /// et aucun jeton d'accès n'est stocké. La valeur provient toujours d'une
  /// réponse du serveur (`requiresOtp` / `phoneVerified: false`).
  PendingVerification? _pendingVerification;

  bool _isVerifyingOtp = false;
  bool _isResendingOtp = false;
  String? _otpError;
  OtpFailure? _otpFailure;
  int _otpResendCooldown = 0;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isGoogleSignInInProgress => _isGoogleSignInInProgress;

  /// `true` tant que le serveur n'a pas confirmé la vérification du numéro.
  bool get needsPhoneVerification => _pendingVerification != null;

  /// Vérification en attente (numéro, UID, origine du parcours).
  PendingVerification? get pendingVerification => _pendingVerification;

  bool get isVerifyingOtp => _isVerifyingOtp;
  bool get isResendingOtp => _isResendingOtp;

  /// Dernier message d'erreur de la vérification (code faux, expiré…).
  String? get otpError => _otpError;

  /// Nature du dernier échec — permet à l'écran de proposer un renvoi.
  OtpFailure? get otpFailure => _otpFailure;

  /// Secondes restantes avant de pouvoir redemander un code.
  int get otpResendCooldown => _otpResendCooldown;

  /// Bloque les doubles clics sur le bouton Google.
  bool get isBusy => _isLoading || _isGoogleSignInInProgress;
  String? get error => _error;

  @override
  void dispose() {
    _otpService.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();

    // Vérification OTP laissée en suspens (application tuée, perte réseau) :
    // on la restaure AVANT de décider de l'écran à afficher.
    _pendingVerification = await _authService.getPendingVerification();

    _isLoggedIn = await _authService.isLoggedIn();
    if (_isLoggedIn && _pendingVerification == null) {
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
    // Jamais bloquant : l'absence de plugin de liens profonds (tests,
    // certaines plateformes) ne doit pas empêcher la vérification OTP.
    try {
      await GoogleOAuthFlow.instance.start();
    } catch (e) {
      debugPrint('[AuthProvider] écoute des deep links indisponible: $e');
    }

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

    // Session temps réel : c'est elle qui rend l'utilisateur « présent » pour
    // le backend. Sans elle, les messages qui lui sont destinés basculent en
    // SMS (routage côté serveur) alors qu'il utilise bien l'application.
    if (_isLoggedIn) {
      await _startRealtime();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Ouvre la session Socket.IO avec le JWT OmniSMS déjà stocké.
  Future<void> _startRealtime() async {
    try {
      final token = await _authService.getToken();
      final userId = _currentUser?.id.isNotEmpty == true
          ? _currentUser!.id
          : await _authService.getUserId();
      if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
        return;
      }
      await RealtimeService.instance.connect(token: token, uid: userId);
    } catch (e) {
      // Jamais bloquant : le polling reste opérationnel.
      debugPrint('[AuthProvider] session temps réel indisponible: $e');
    }
  }

  /// Inscription — `username` est OBLIGATOIRE côté backend
  /// (POST /api/auth/register renvoie 400 « Le nom d'utilisateur est requis. »).
  /// `phone` est le canal principal (SMS/Infobip) : il reste requis par la PWA,
  /// `email` est optionnel.
  Future<bool> register({
    required String name,
    required String password,
    required String username,
    String? email,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        name: name,
        password: password,
        username: username,
        email: email,
        phone: phone,
      );

      if (result['success']) {
        // Le serveur exige la vérification du numéro : la session reste
        // FERMÉE et le jeton éventuel n'est qu'un jeton d'attente.
        if (result['requiresOtp'] == true) {
          _pendingVerification = result['verification'] as PendingVerification?;
          _currentUser = result['user'];
          _isLoggedIn = false;
          _isLoading = false;
          notifyListeners();
          return true;
        }

        _currentUser = result['user'];
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        await _startRealtime();
        return true;
      } else {
        _error = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = "Erreur lors de l'inscription";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Connexion par email OU numéro de téléphone (même heuristique que la PWA).
  Future<bool> login({
    String? identifier,
    String? email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        identifier: identifier ?? email,
        email: email,
        password: password,
      );

      if (result['success']) {
        // Compte existant non vérifié : on reprend le parcours OTP sans
        // ouvrir la session.
        if (result['requiresOtp'] == true) {
          _pendingVerification = result['verification'] as PendingVerification?;
          _currentUser = result['user'];
          _isLoggedIn = false;
          _isLoading = false;
          notifyListeners();
          return true;
        }

        _currentUser = result['user'];
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        await _startRealtime();
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
        // Compte Google neuf ou compte existant non vérifié : le serveur
        // décide. Aucune session ni temps réel avant confirmation.
        if (result['requiresOtp'] == true) {
          _pendingVerification = result['verification'] as PendingVerification?;
          _currentUser = result['user'];
          _isLoggedIn = false;
          _isGoogleSignInInProgress = false;
          notifyListeners();
          return true;
        }

        _currentUser = result['user'];
        _isLoggedIn = true;
        _isGoogleSignInInProgress = false;
        notifyListeners();
        // Session temps réel : l'utilisateur devient joignable en interne.
        await _startRealtime();
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

  // ── Vérification du numéro par OTP ───────────────────────────────

  /// Redemande l'envoi d'un code.
  ///
  /// Retourne le résultat brut : l'écran s'en sert pour démarrer le compte à
  /// rebours (même en cas de refus pour cause de délai trop court).
  Future<OtpSendResult> resendOtp() async {
    final pending = _pendingVerification;
    if (pending == null) {
      return const OtpSendResult.failure(
        OtpFailure.unknown,
        'Aucune vérification en cours.',
      );
    }
    if (_isResendingOtp) {
      return const OtpSendResult.failure(
        OtpFailure.unknown,
        'Une demande est déjà en cours.',
      );
    }

    _isResendingOtp = true;
    _otpError = null;
    _otpFailure = null;
    notifyListeners();

    try {
      final result = await _otpService.sendCode(
        phone: pending.phone,
        userId: pending.userId,
        pendingToken: pending.pendingToken,
      );

      if (result.ok) {
        _otpResendCooldown = result.cooldownSeconds;
      } else {
        // Même un échec de type « délai » porte la durée à respecter.
        _otpResendCooldown = result.cooldownSeconds;
        _otpError = result.message;
        _otpFailure = result.failure;
      }
      _isResendingOtp = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isResendingOtp = false;
      _otpError = 'Impossible de renvoyer le code. Réessayez.';
      _otpFailure = OtpFailure.network;
      notifyListeners();
      return const OtpSendResult.failure(
        OtpFailure.network,
        'Impossible de renvoyer le code. Réessayez.',
      );
    }
  }

  /// Transmet le code saisi au serveur.
  ///
  /// La session n'est ouverte QUE si le serveur confirme et renvoie un
  /// jeton d'accès. Aucun contrôle local du code n'est effectué : le
  /// frontend ne sait pas si un code est valide.
  Future<bool> verifyOtp(String code) async {
    final pending = _pendingVerification;
    if (pending == null) {
      _otpError = 'Aucune vérification en cours.';
      _otpFailure = OtpFailure.unknown;
      notifyListeners();
      return false;
    }
    if (_isVerifyingOtp) return false; // anti double soumission

    _isVerifyingOtp = true;
    _otpError = null;
    _otpFailure = null;
    notifyListeners();

    try {
      final result = await _otpService.verifyCode(
        phone: pending.phone,
        code: code,
        userId: pending.userId,
        pendingToken: pending.pendingToken,
      );

      if (result.ok && result.token != null && result.token!.isNotEmpty) {
        // ── Seule porte d'entrée de la session ──
        // Le jeton d'attente est remplacé par le jeton d'accès renvoyé
        // après vérification confirmée par le serveur.
        await _authService.completeVerification(
          token: result.token!,
          userId: result.user?.id ?? pending.userId,
        );

        _pendingVerification = null;
        _currentUser = result.user ?? _currentUser;
        _isLoggedIn = true;
        _isVerifyingOtp = false;
        _otpResendCooldown = 0;
        notifyListeners();

        await _startRealtime();
        return true;
      }

      _otpError = result.message;
      _otpFailure = result.failure;
      _isVerifyingOtp = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isVerifyingOtp = false;
      _otpError = 'Impossible de vérifier le code. Réessayez.';
      _otpFailure = OtpFailure.network;
      notifyListeners();
      return false;
    }
  }

  /// Décrémente le compte à rebours de renvoi (appelé par l'écran).
  void tickOtpCooldown() {
    if (_otpResendCooldown <= 0) return;
    _otpResendCooldown--;
    notifyListeners();
  }

  void clearOtpError() {
    _otpError = null;
    _otpFailure = null;
    notifyListeners();
  }

  /// Abandonne la vérification en cours (retour à l'écran de connexion).
  /// Le compte, s'il a été créé, reste en attente côté serveur : aucune
  /// session n'est ouverte.
  Future<void> cancelVerification() async {
    await _authService.clearPendingVerification();
    _pendingVerification = null;
    _otpError = null;
    _otpFailure = null;
    _otpResendCooldown = 0;
    notifyListeners();
  }

  /// Mise à jour du profil — PUT /api/me/profile (name, username, phone,
  /// email, password optionnel ≥ 8 caractères).
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? username,
    String? password,
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
        username: username,
        password: password,
        photoUrl: photoUrl,
      );

      if (result['success']) {
        // Le backend renvoie l'utilisateur mis à jour ; à défaut on recharge
        // depuis /api/me (comme le fait refreshUserProfile() dans la PWA).
        final refreshed = (result['user'] as UserModel?) ??
            await _authService.getCurrentUser();
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

  /// Upload de la photo de profil — POST /api/me/avatar.
  /// [bytes]/[filename] fonctionnent partout ; [filePath] est un raccourci mobile.
  Future<bool> uploadAvatar({
    List<int>? bytes,
    String? filename,
    String? filePath,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.uploadAvatar(
        bytes: bytes,
        filename: filename,
        filePath: filePath,
      );

      if (result['success'] == true) {
        final refreshed = (result['user'] as UserModel?) ??
            await _authService.getCurrentUser();
        if (refreshed != null) {
          _currentUser = refreshed;
        } else if (result['avatarUrl'] != null) {
          _currentUser = _currentUser?.copyWith(
                photoUrl: result['avatarUrl'].toString(),
              ) ??
              UserModel(id: '', photoUrl: result['avatarUrl'].toString());
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = result['message'] ?? "Échec de l'upload";
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = "Échec de l'upload de la photo";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Suppression définitive du compte — DELETE /api/me.
  /// En cas de succès la session locale est purgée (AuthService.logout()).
  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.deleteAccount();

      if (result['success'] == true) {
        _currentUser = null;
        _isLoggedIn = false;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = result['message'];
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erreur lors de la suppression du compte';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    // La présence doit disparaître AVANT la suppression du jeton : sinon le
    // backend continue de considérer l'utilisateur comme connecté.
    RealtimeService.instance.disconnect();
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
