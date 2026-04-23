import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  // 🌐 Nouveau lien de paiement GitHub Pages
  static const String subscriptionUrl = 'https://emstronglezin-cmd.github.io/omnisms-site/';

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb && MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: isWeb ? const Color(0xFF080c14) : null,
      appBar: AppBar(
        title: const Text('Abonnement Premium'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icône Premium
            Container(
              padding: const EdgeInsets.all(32),
              child: Icon(
                Icons.workspace_premium,
                size: 120,
                color: Theme.of(context).primaryColor,
              ),
            ),

            // Titre
            Text(
              'OmniSMS Premium',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isWeb ? const Color(0xFFe8edf5) : null,
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Prix
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isWeb
                      ? [const Color(0xFF00d4ff), const Color(0xFF0066ff)]
                      : [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.7),
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

            // Avantages
            _buildFeatureItem(
              context,
              Icons.sms,
              'SMS illimités',
              'Envoyez autant de SMS que vous voulez',
              isWeb,
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              Icons.group,
              'Groupes illimités',
              'Créez et gérez des groupes sans limite',
              isWeb,
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              Icons.mic,
              'Messages vocaux',
              'Enregistrez et transcrivez vos messages vocaux',
              isWeb,
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              Icons.notifications_active,
              'Notifications push',
              'Recevez vos messages en temps réel',
              isWeb,
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              Icons.cloud_done,
              'Synchronisation cloud',
              'Accédez à vos messages depuis n\'importe où',
              isWeb,
            ),

            const SizedBox(height: 40),

            // Bouton S'abonner
            ElevatedButton.icon(
              onPressed: () => _launchSubscriptionUrl(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isWeb
                    ? const Color(0xFF00d4ff)
                    : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.shopping_cart, size: 28),
              label: const Text(
                'S\'abonner maintenant',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Note de sécurité
            Text(
              '🔒 Paiement sécurisé',
              style: TextStyle(
                color: isWeb
                    ? const Color(0xFF6b7a96)
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Info
            Text(
              'Vous serez redirigé vers notre page de paiement sécurisée',
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
                color: const Color(0xFF00d4ff).withOpacity(0.2),
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
                  : Theme.of(context).primaryColor.withOpacity(0.1),
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
                    color: isWeb ? const Color(0xFFe8edf5) : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isWeb
                        ? const Color(0xFF6b7a96)
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchSubscriptionUrl(BuildContext context) async {
    try {
      if (await canLaunchUrlString(subscriptionUrl)) {
        await launchUrlString(
          subscriptionUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'ouvrir la page d\'abonnement'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
