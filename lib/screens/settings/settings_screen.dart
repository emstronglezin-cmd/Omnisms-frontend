import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // Profil
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          const Divider(),
          // Notifications
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/settings/notifications'),
          ),
          // Thème
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Thème'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/settings/theme'),
          ),
          // Statistiques
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Statistiques'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(context, '/settings/statistics'),
          ),
          const Divider(),
          // À propos
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('À propos'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'OmniSMS',
                applicationVersion: '2.1.0',
              );
            },
          ),
        ],
      ),
    );
  }
}
