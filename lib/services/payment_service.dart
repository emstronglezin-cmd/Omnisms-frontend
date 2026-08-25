import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

/// PaymentService — Connexion réelle au backend OmniSMS / LeekPay
///
/// Routes utilisées :
///   POST /api/payment/leekpay            → crée un checkout, retourne checkout_url
///   GET  /api/payment/user-status        → vérifie si l'user est Premium
///   GET  /api/payment/status/:id         → statut d'un paiement
class PaymentService {
  final AuthService _authService = AuthService();

  // ── Initier un paiement LeekPay ──────────────────────────────
  /// Retourne { success, checkoutUrl, checkoutId, orderId, error }
  Future<Map<String, dynamic>> initiateLeekPayPayment({
    required String userId,
    double amount = 2000,
    String currency = 'XOF',
    String? phone,
    String? email,
    String? name,
  }) async {
    try {
      final token = await _authService.getToken();

      // SÉCURITÉ : le montant/currency sont désormais fixés côté serveur
      // (2000 XOF) — on ne les envoie plus pour éviter toute manipulation.
      final body = <String, dynamic>{
        'userId': userId,
      };
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (name != null && name.isNotEmpty) body['name'] = name;

      // Le backend exige désormais le token Bearer sur /api/payment/leekpay
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'error': 'Session expirée. Reconnectez-vous.',
        };
      }

      final headers = <String, String>{
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      };

      debugPrint('[Payment] POST /api/payment/leekpay');

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/payment/leekpay'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.wakeupTimeout);

      // SÉCURITÉ : ne plus logger le corps complet de la réponse
      debugPrint('[Payment] Response status: ${response.statusCode}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final checkoutUrl = data['checkout_url'] as String?;
        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          return {
            'success': false,
            'error': 'Le backend n\'a pas retourné d\'URL de paiement.',
          };
        }
        return {
          'success': true,
          'checkoutUrl': checkoutUrl,
          'checkoutId': data['checkout_id'],
          'orderId': data['orderId'],
          'amount': data['amount'],
          'currency': data['currency'],
        };
      } else if (response.statusCode == 400 &&
          data['code'] == 'ALREADY_SUBSCRIBED') {
        return {
          'success': false,
          'alreadySubscribed': true,
          'error': data['error'] ?? 'Vous êtes déjà abonné Premium.',
        };
      } else if (response.statusCode == 503 &&
          data['code'] == 'LEEKPAY_NOT_CONFIGURED') {
        return {
          'success': false,
          'error':
              'Le service de paiement n\'est pas encore configuré. Contactez l\'administrateur.',
          'code': 'LEEKPAY_NOT_CONFIGURED',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Erreur lors de la création du paiement.',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error':
            'Le serveur met du temps à répondre. Réessayez dans quelques secondes.',
      };
    } catch (e) {
      debugPrint('[Payment] Error: $e');
      return {
        'success': false,
        'error': 'Erreur réseau : ${_friendlyError(e)}',
      };
    }
  }

  // ── Vérifier le statut Premium d'un utilisateur ──────────────
  Future<Map<String, dynamic>> getUserPremiumStatus(String userId) async {
    try {
      final token = await _authService.getToken();
      final headers = <String, String>{
        ...ApiConfig.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}/api/payment/user-status?userId=${Uri.encodeComponent(userId)}'),
            headers: headers,
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'premium': data['premium'] ?? false,
          'isSubscribed': data['isSubscribed'] ?? false,
          'subscribedAt': data['subscribedAt'],
        };
      }
      return {'success': false, 'premium': false};
    } catch (e) {
      debugPrint('[Payment] getUserPremiumStatus error: $e');
      return {'success': false, 'premium': false};
    }
  }

  // ── Vérifier le statut d'un paiement ─────────────────────────
  Future<Map<String, dynamic>> getPaymentStatus(String transactionId) async {
    try {
      final token = await _authService.getToken();
      final headers = <String, String>{
        ...ApiConfig.headers,
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.baseUrl}/api/payment/status/${Uri.encodeComponent(transactionId)}'),
            headers: headers,
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'status': data['status'],
          'premiumActivated': data['premiumActivated'] ?? false,
          'amount': data['amount'],
          'currency': data['currency'],
          'paidAt': data['paidAt'],
        };
      }
      return {'success': false, 'status': 'unknown'};
    } catch (e) {
      debugPrint('[Payment] getPaymentStatus error: $e');
      return {'success': false, 'status': 'error'};
    }
  }

  // ── Helper messages d'erreur ─────────────────────────────────
  static String _friendlyError(dynamic e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
    }
    if (s.contains('XMLHttpRequest') || s.contains('CORS')) {
      return 'Erreur CORS. Contactez le support.';
    }
    return s;
  }
}
