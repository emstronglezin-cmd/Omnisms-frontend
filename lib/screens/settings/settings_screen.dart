import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../providers/auth_provider.dart';
import '../auth/profile_screen.dart';
import 'notifications_settings_screen.dart';
import 'theme_settings_screen.dart';
import 'statistics_screen.dart';
import '../../screens/subscription_screen.dart';

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
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: user?.photoUrl != null
                      ? ClipOval(
                          child: Image.network(
                            user!.photoUrl!,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 35,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Icon(
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
                      if (user?.email != null)
                        Text(
                          user!.email!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
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
            subtitle: const Text('Version 2.2.0'),
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
                  const Text('Backend: http://51.15.89.72:5000'),
                  const SizedBox(height: 8),
                  const Text('🔥 Crashlytics: Activé'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
