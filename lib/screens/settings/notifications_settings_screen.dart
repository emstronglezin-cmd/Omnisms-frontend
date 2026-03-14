import 'package:flutter/material.dart';
import '../../services/settings_service.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  
  bool _notificationsEnabled = true;
  bool _soundsEnabled = true;
  bool _alertsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications = await _settingsService.getNotificationsEnabled();
    final sounds = await _settingsService.getSoundsEnabled();
    final alerts = await _settingsService.getAlertsEnabled();

    setState(() {
      _notificationsEnabled = notifications;
      _soundsEnabled = sounds;
      _alertsEnabled = alerts;
      _isLoading = false;
    });
  }

  Future<void> _updateNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    await _settingsService.setNotificationsEnabled(value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Notifications activées' : 'Notifications désactivées',
          ),
        ),
      );
    }
  }

  Future<void> _updateSounds(bool value) async {
    setState(() {
      _soundsEnabled = value;
    });
    await _settingsService.setSoundsEnabled(value);
  }

  Future<void> _updateAlerts(bool value) async {
    setState(() {
      _alertsEnabled = value;
    });
    await _settingsService.setAlertsEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gérer les notifications',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Configurez comment vous souhaitez être notifié',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Notifications
                SwitchListTile(
                  value: _notificationsEnabled,
                  onChanged: _updateNotifications,
                  title: const Text('Notifications'),
                  subtitle: const Text(
                    'Recevoir des notifications pour les nouveaux messages',
                  ),
                  secondary: Icon(
                    _notificationsEnabled
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                  ),
                ),

                const Divider(),

                // Sounds
                SwitchListTile(
                  value: _soundsEnabled,
                  onChanged: _updateSounds,
                  title: const Text('Sons'),
                  subtitle: const Text('Jouer un son lors de la réception'),
                  secondary: Icon(
                    _soundsEnabled ? Icons.volume_up : Icons.volume_off,
                  ),
                ),

                const Divider(),

                // Alerts
                SwitchListTile(
                  value: _alertsEnabled,
                  onChanged: _updateAlerts,
                  title: const Text('Alertes'),
                  subtitle: const Text('Afficher des alertes à l\'écran'),
                  secondary: Icon(
                    _alertsEnabled ? Icons.announcement : Icons.announcement_outlined,
                  ),
                ),

                const SizedBox(height: 24),

                // Info Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Les paramètres sont synchronisés avec le serveur',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
