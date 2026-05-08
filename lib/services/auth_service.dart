import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Register ──────────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      // Créer le compte Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return {'success': false, 'message': 'Erreur lors de la création du compte.'};
      }

      // Mettre à jour le nom dans Firebase Auth
      await user.updateDisplayName(name);

      // Sauvegarder dans Firestore
      final now = DateTime.now().toIso8601String();
      await _firestore.collection('users').doc(user.uid).set({
        'name'        : name,
        'email'       : email.toLowerCase().trim(),
        'phone'       : phone,
        'isSubscribed': false,
        'credits'     : 0,
        'provider'    : 'email',
        'createdAt'   : now,
        'updatedAt'   : now,
      });

      // Récupérer le token
      final token = await user.getIdToken();
      await _saveToken(token!);
      await _saveUserId(user.uid);

      return {
        'success': true,
        'message': 'Inscription réussie',
        'token'  : token,
        'user'   : UserModel(
          id          : user.uid,
          name        : name,
          email       : email,
          isSubscribed: false,
          credits     : 0,
        ),
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Un compte avec cet email existe déjà.';
          break;
        case 'weak-password':
          message = 'Le mot de passe est trop faible.';
          break;
        case 'invalid-email':
          message = 'Adresse email invalide.';
          break;
        default:
          message = 'Erreur: ${e.message}';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ── Login ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return {'success': false, 'message': 'Erreur lors de la connexion.'};
      }

      final token = await user.getIdToken();
      await _saveToken(token!);
      await _saveUserId(user.uid);

      // Récupérer les données depuis Firestore
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      return {
        'success': true,
        'message': 'Connexion réussie',
        'token'  : token,
        'user'   : UserModel(
          id          : user.uid,
          name        : data['name'] ?? user.displayName ?? '',
          email       : user.email ?? email,
          isSubscribed: data['isSubscribed'] ?? false,
          credits     : data['credits'] ?? 0,
        ),
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Aucun compte trouvé avec cet email.';
          break;
        case 'wrong-password':
          message = 'Mot de passe incorrect.';
          break;
        case 'invalid-email':
          message = 'Adresse email invalide.';
          break;
        case 'user-disabled':
          message = 'Ce compte a été désactivé.';
          break;
        case 'too-many-requests':
          message = 'Trop de tentatives. Réessayez plus tard.';
          break;
        default:
          message = 'Erreur: ${e.message}';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ── Get current user ──────────────────────────────────────
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      return UserModel(
        id          : user.uid,
        name        : data['name'] ?? user.displayName ?? '',
        email       : user.email ?? '',
        isSubscribed: data['isSubscribed'] ?? false,
        credits     : data['credits'] ?? 0,
      );
    } catch (e) {
      return null;
    }
  }

  // ── Update profile ────────────────────────────────────────
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Non authentifié.'};
      }

      final updates = <String, dynamic>{'updatedAt': DateTime.now().toIso8601String()};
      if (name != null)  { updates['name']  = name;  await user.updateDisplayName(name); }
      if (phone != null)   updates['phone']  = phone;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      await _firestore.collection('users').doc(user.uid).update(updates);

      return {'success': true, 'message': 'Profil mis à jour.'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // ── Logout ────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  // ── isLoggedIn ────────────────────────────────────────────
  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  // ── Token helpers ─────────────────────────────────────────
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final user = _auth.currentUser;
    if (user != null) return await user.getIdToken();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  Future<String?> getUserId() async {
    return _auth.currentUser?.uid;
  }
}
