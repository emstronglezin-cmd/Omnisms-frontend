import 'package:omnisms/models/models.dart';
import 'package:omnisms/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faux service d'authentification : isole le provider du réseau et de
/// SharedPreferences réels (les préférences sont simulées par les tests).
class FakeAuthService extends AuthService {
  Map<String, dynamic>? nextRegisterResult;
  Map<String, dynamic>? nextLoginResult;
  Map<String, dynamic>? nextGoogleResult;

  String? savedToken;
  String? savedUserId;

  Future<void> seedPendingVerification(PendingVerification pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'pending_phone_verification', pending.toJsonString());
  }

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String password,
    required String username,
    String? email,
    String? phone,
  }) async {
    return nextRegisterResult ?? {'success': false, 'message': 'non configuré'};
  }

  @override
  Future<Map<String, dynamic>> login({
    String? identifier,
    String? email,
    String? password,
  }) async {
    return nextLoginResult ?? {'success': false, 'message': 'non configuré'};
  }

  @override
  Future<Map<String, dynamic>> loginWithGoogle() async {
    return nextGoogleResult ?? {'success': false, 'message': 'non configuré'};
  }

  @override
  Future<bool> isLoggedIn() async => false;

  @override
  Future<UserModel?> getCurrentUser() async => null;

  /// Renvoie toujours `null` : les tests ne doivent jamais déclencher de
  /// connexion Socket.IO réelle (cela marquerait un vrai utilisateur
  /// « en ligne » sur la production).
  @override
  Future<String?> getToken() async => null;

  @override
  Future<String?> getUserId() async => savedUserId;

  @override
  Future<void> completeVerification({
    required String token,
    String? userId,
  }) async {
    savedToken = token;
    savedUserId = userId;
    await clearPendingVerification();
  }

  @override
  Future<Map<String, dynamic>> recoverGoogleLoginIfPending() async =>
      {'success': false, 'message': ''};
}
