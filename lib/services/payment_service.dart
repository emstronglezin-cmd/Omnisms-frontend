import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// This file contains external payment APIs.
// DO NOT USE directly in the application.

class PaymentService {
  Future<bool> createPayment(String method, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/payments/create'),
        headers: ApiConfig.defaultHeaders,
        body: json.encode({'method': method, 'amount': amount}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Erreur lors de la création du paiement: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Erreur PaymentService.createPayment: $e');
      return false;
    }
  }

  Future<bool> verifyPayment(String paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payments/verify/$paymentId'),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Erreur lors de la vérification du paiement: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Erreur PaymentService.verifyPayment: $e');
      return false;
    }
  }
}
