import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/payment_service.dart';

/// SubscriptionScreen — Abonnement Premium OmniSMS
///
/// Workflow :
///   1. Utilisateur clique "S'abonner maintenant"
///   2. POST /api/payment/leekpay { userId, amount, currency }
///   3. Backend retourne { success, checkout_url }
///   4. On ouvre checkout_url dans le navigateur
///   5. LeekPay → webhook → Firebase premium activé
///   6. Au retour, on vérifie le statut premium
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final PaymentService _paymentService = PaymentService();

  bool _isLoading = false;
  bool _isPremium = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  // ── Vérifier le statut Premium actuel ───────────────────────
  Future<void> _checkPremiumStatus() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      final result = await _paymentService.getUserPremiumStatus(userId);
      if (mounted) {
        setState(() {
          _isPremium = result['premium'] == true ||
              result['isSubscribed'] == true;
        });
      }
    } catch (e) {
      debugPrint('[Subscription] checkPremiumStatus error: $e');
    }
  }

  // ── Lancer le paiement LeekPay ───────────────────────────────
  Future<void> _handleSubscribePressed() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;

    if (user == null) {
      setState(() {
        _errorMessage =
            'Vous devez être connecté pour vous abonner.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      debugPrint('[Subscription] Initiating payment for userId=${user.id}');

      final result = await _paymentService.initiateLeekPayPayment(
        userId: user.id,
        amount: 2000,
        currency: 'XOF',
        email: user.email,
        name: user.name ?? '',
      );

      debugPrint('[Subscription] Payment result: $result');

      if (!mounted) return;

      if (result['success'] == true) {
        final checkoutUrl = result['checkoutUrl'] as String;
        await _openCheckoutUrl(checkoutUrl);
      } else if (result['alreadySubscribed'] == true) {
        setState(() {
          _isPremium = true;
          _successMessage = 'Vous êtes déjà abonné OmniSMS Premium !';
          _isLoading = false;
        });
      } else {
        // LeekPay non configuré → fallback URL GitHub Pages
        if (result['code'] == 'LEEKPAY_NOT_CONFIGURED') {
          await _openFallbackUrl();
        } else {
          setState(() {
            _errorMessage = result['error'] ??
                'Impossible de créer le paiement. Réessayez.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur inattendue : $e';
          _isLoading = false;
        });
      }
    }
  }

  // ── Ouvrir l'URL de paiement LeekPay ────────────────────────
  Future<void> _openCheckoutUrl(String checkoutUrl) async {
    try {
      final uri = Uri.parse(checkoutUrl);
      bool launched = false;

      if (kIsWeb) {
        // Sur web : ouvrir dans un nouvel onglet
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (mounted) {
        if (launched) {
          setState(() {
            _successMessage =
                'Page de paiement ouverte. Revenez ici après avoir complété le paiement.';
            _isLoading = false;
          });
          // Vérifier le statut après 5 secondes (retour de la page)
          Future.delayed(const Duration(seconds: 10), () {
            if (mounted) _checkPremiumStatus();
          });
        } else {
          setState(() {
            _errorMessage =
                'Impossible d\'ouvrir la page de paiement. URL : $checkoutUrl';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[Subscription] openCheckoutUrl error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur lors de l\'ouverture de la page : $e';
          _isLoading = false;
        });
      }
    }
  }

  // ── Fallback si LeekPay non configuré ────────────────────────
  Future<void> _openFallbackUrl() async {
    const fallbackUrl =
        'https://emstronglezin-cmd.github.io/omnisms-site/';
    try {
      final uri = Uri.parse(fallbackUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        setState(() {
          _successMessage =
              'Page d\'abonnement ouverte. Le paiement en ligne sera disponible prochainement.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible d\'ouvrir la page : $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb =
        kIsWeb && MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor:
          isWeb ? const Color(0xFF080c14) : null,
      appBar: AppBar(
        title: const Text('Abonnement Premium'),
        centerTitle: true,
        actions: [
          // Refresh premium status
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser le statut',
            onPressed: _checkPremiumStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Badge Premium si déjà abonné ─────────────────
            if (_isPremium)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00c853), Color(0xFF69f0ae)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Vous êtes déjà Premium !',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Bannière erreur ───────────────────────────────
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _errorMessage = null),
                      child: const Icon(Icons.close,
                          color: Colors.red, size: 16),
                    ),
                  ],
                ),
              ),

            // ── Bannière succès ───────────────────────────────
            if (_successMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.green.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(
                            color: Colors.green, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Icône Premium ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(32),
              child: Icon(
                Icons.workspace_premium,
                size: 120,
                color: _isPremium
                    ? Colors.green
                    : Theme.of(context).primaryColor,
              ),
            ),

            // ── Titre ─────────────────────────────────────────
            Text(
              'OmniSMS Premium',
              style:
                  Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isWeb
                            ? const Color(0xFFe8edf5)
                            : null,
                      ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // ── Prix ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isWeb
                      ? [
                          const Color(0xFF00d4ff),
                          const Color(0xFF0066ff)
                        ]
                      : [
                          Theme.of(context).primaryColor,
                          Theme.of(context)
                              .primaryColor
                              .withOpacity(0.7),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    '2000 FCFA',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'par mois',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Avantages ─────────────────────────────────────
            _buildFeatureItem(context, Icons.sms, 'SMS illimités',
                'Envoyez autant de SMS que vous voulez', isWeb),
            const SizedBox(height: 16),
            _buildFeatureItem(
                context,
                Icons.group,
                'Groupes illimités',
                'Créez et gérez des groupes sans limite',
                isWeb),
            const SizedBox(height: 16),
            _buildFeatureItem(
                context,
                Icons.mic,
                'Messages vocaux',
                'Enregistrez et transcrivez vos messages vocaux',
                isWeb),
            const SizedBox(height: 16),
            _buildFeatureItem(
                context,
                Icons.notifications_active,
                'Notifications push',
                'Recevez vos messages en temps réel',
                isWeb),
            const SizedBox(height: 16),
            _buildFeatureItem(
                context,
                Icons.cloud_done,
                'Synchronisation cloud',
                'Accédez à vos messages depuis n\'importe où',
                isWeb),

            const SizedBox(height: 40),

            // ── Bouton S'abonner ──────────────────────────────
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _isPremium)
                    ? null
                    : _handleSubscribePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPremium
                      ? Colors.green
                      : (isWeb
                          ? const Color(0xFF00d4ff)
                          : Theme.of(context).primaryColor),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  disabledBackgroundColor:
                      _isPremium ? Colors.green : null,
                  disabledForegroundColor:
                      _isPremium ? Colors.white : null,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isPremium
                            ? Icons.verified
                            : Icons.shopping_cart,
                        size: 26,
                      ),
                label: Text(
                  _isLoading
                      ? 'Création du paiement…'
                      : (_isPremium
                          ? 'Premium actif ✓'
                          : 'S\'abonner maintenant'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Sécurité ──────────────────────────────────────
            Text(
              '🔒 Paiement sécurisé via LeekPay (Mobile Money & Carte)',
              style: TextStyle(
                color: isWeb
                    ? const Color(0xFF6b7a96)
                    : Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'Vous serez redirigé vers la page de paiement sécurisée LeekPay',
              style: TextStyle(
                fontSize: 12,
                color: isWeb
                    ? const Color(0xFF6b7a96)
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    bool isWeb,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWeb ? const Color(0xFF0f1520) : null,
        border: isWeb
            ? Border.all(
                color:
                    const Color(0xFF00d4ff).withOpacity(0.2),
              )
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isWeb
                  ? const Color(0xFF00d4ff).withOpacity(0.1)
                  : Theme.of(context)
                      .primaryColor
                      .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isWeb
                  ? const Color(0xFF00d4ff)
                  : Theme.of(context).primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        isWeb ? const Color(0xFFe8edf5) : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isWeb
                        ? const Color(0xFF6b7a96)
                        : Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
