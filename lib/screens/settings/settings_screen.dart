import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import 'gateway_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider.dart';
import '../auth/profile_screen.dart';
import 'notifications_settings_screen.dart';
import 'theme_settings_screen.dart';
import 'statistics_screen.dart';
import '../../screens/subscription_screen.dart';
import '../../widgets/common/avatar_image.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          // User Header
          Container(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                UserAvatar(
                  imageUrl: user?.photoUrl,
                  name: user?.name ?? 'Utilisateur',
                  size: 70,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  fallback: const Icon(
                    Icons.person,
                    size: 35,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Utilisateur',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user?.username != null && user!.username!.isNotEmpty)
                        Text(
                          '@${user.username}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (user?.email != null)
                        Text(
                          user!.email!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (user?.phone != null && user!.phone!.isNotEmpty)
                        Text(
                          user.phone!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      const SizedBox(height: 6),
                      // Badge Premium (PWA : renderSettings())
                      if (user?.isPremium == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D4FF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF00D4FF).withOpacity(0.4),
                            ),
                          ),
                          child: const Text(
                            '💎 Premium actif',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00D4FF),
                            ),
                          ),
                        ),
                      // Avertissement téléphone manquant (PWA : renderSettings())
                      if (user != null &&
                          (user.phone == null || user.phone!.isEmpty))
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            '⚠️ Téléphone non renseigné',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          
          // Settings Items
          ListTile(
            leading: const Icon(Icons.person_outlined),
            title: const Text('Profil'),
            subtitle: const Text('Modifier vos informations'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Gérer les notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsSettingsScreen(),
                ),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Thème'),
            subtitle: const Text('Apparence de l\'application'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Statistiques'),
            subtitle: const Text('Votre activité'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Abonnement'),
            subtitle: const Text('Gérer votre abonnement'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
          ),
          
          // ── Informations légales ───────────────────────────
          // Page intégrée à l'application : disponible immédiatement, sans
          // dépendre d'une URL externe encore non renseignée.
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Politique de confidentialité'),
            subtitle: const Text(
              'Données traitées, finalités, destinataires et vos droits',
            ),
            onTap: () => Navigator.of(context).pushNamed('/privacy'),
          ),

          // ── Version web publiée ─────────────────────────────
          // Affichée uniquement si ApiConfig.privacyPolicyUrl est renseigné :
          // mieux vaut aucune entrée qu'une entrée qui n'ouvre rien.
          // (Utile pour la revue App Store, qui exige une URL publique.)
          if (ApiConfig.hasPrivacyPolicy)
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Politique de confidentialité (en ligne)'),
              subtitle: const Text(
                'Ouvrir la version publiée dans le navigateur',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final uri = Uri.parse(ApiConfig.privacyPolicyUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),

          const Divider(),

          // ── Compte (PWA : renderSettings()) ─────────────────
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Se déconnecter'),
            subtitle: const Text('Fermer la session de cet appareil'),
            onTap: () => _confirmLogout(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Supprimer mon compte',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Action irréversible'),
            onTap: () => _confirmDeleteAccount(context),
          ),
          ListTile(
            leading: const Icon(Icons.router_outlined),
            title: const Text('Passerelle SMS'),
            subtitle: const Text('État du service d’envoi des SMS'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GatewayScreen(),
              ),
            ),
          ),
          // Parcours web public : exigé par Google Play et par l'App Store
          // pour les comptes créés depuis l'application. Il fonctionne même
          // si l'utilisateur n'a plus accès à l'app ou a perdu son compte.
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Supprimer mon compte depuis le web'),
            subtitle: const Text('Page publique de suppression de compte'),
            onTap: () => _openAccountDeletionWebPage(context),
          ),

          const Divider(),
          
          // 🔥 TEST CRASHLYTICS (DEBUG ONLY)
          if (!const bool.fromEnvironment('dart.vm.product'))
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text('Test Crash (Debug)'),
              subtitle: const Text('Tester Firebase Crashlytics'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Test Crashlytics'),
                    content: const Text(
                      'Ceci va forcer un crash pour tester Crashlytics. Continuer ?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Tester'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true && !kIsWeb) {
                  // Force a crash for testing (mobile only)
                  // FirebaseCrashlytics.instance.crash();
                  debugPrint('Crash test triggered (no-op on web)');
                }
              },
            ),
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos'),
            subtitle: const Text('Version 2.5.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'OmniSMS',
                applicationVersion: '2.2.0',
                applicationIcon: Icon(
                  Icons.sms_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                children: [
                  const Text('Messagerie sécurisée et moderne'),
                  const SizedBox(height: 16),
                  // SÉCURITÉ : ne pas afficher l'URL/IP du backend dans l'UI
                  const Text('🔥 Crashlytics: Activé'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }


  // ── Déconnexion ─────────────────────────────────────────────
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // ── Suppression du compte (DELETE /api/me) ──────────────────
  /// Ouvre la page publique de suppression de compte (parcours web exigé
  /// par Google Play et l'App Store). Le lien n'est jamais fabriqué : il
  /// provient de la configuration d'API.
  Future<void> _openAccountDeletionWebPage(BuildContext context) async {
    final uri = Uri.parse(ApiConfig.accountWebUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('[Settings] ouverture page de suppression impossible: $e');
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible d’ouvrir la page de suppression.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: const Text(
          '⚠️ Cette action est irréversible.\n\n'
          '• Votre profil (nom, e-mail, photo, numéro) est effacé ou anonymisé.\n'
          '• Vos contacts et vos conversations sont supprimés.\n'
          '• Vos crédits restants sont perdus : ils ne sont pas remboursables.\n'
          '• Les données résiduelles sont purgées définitivement sous 30 jours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Double confirmation (idem PWA).
    if (!context.mounted) return;
    final confirmed2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Êtes-vous absolument sûr(e) ?'),
        content: const Text('Cette action ne peut pas être annulée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Supprimer définitivement',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed2 != true) return;
    if (!context.mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.deleteAccount();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Compte supprimé. Au revoir !'
            : (auth.error ?? 'Erreur lors de la suppression du compte')),
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}
