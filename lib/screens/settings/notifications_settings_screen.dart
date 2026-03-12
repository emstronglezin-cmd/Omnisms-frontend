import 'package:flutter/material.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool notificationsEnabled = true;
  bool soundEnabled = true;
  bool alertsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Activer/désactiver les notifications'),
            value: notificationsEnabled,
            onChanged: (value) {
              setState(() => notificationsEnabled = value);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Activer les sons'),
            subtitle: const Text('Sons de notification'),
            value: soundEnabled,
            onChanged: notificationsEnabled
                ? (value) {
                    setState(() => soundEnabled = value);
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('Alertes'),
            subtitle: const Text('Alertes de messages importants'),
            value: alertsEnabled,
            onChanged: notificationsEnabled
                ? (value) {
                    setState(() => alertsEnabled = value);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
