import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../services/notification_service.dart';
import '../../services/push_service.dart';
import '../../theme/omni_design.dart';
import '../../theme/omni_motion.dart';

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

  // Permission système actuelle
  bool _hasSystemPermission = false;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications = await _settingsService.getNotificationsEnabled();
    final sounds        = await _settingsService.getSoundsEnabled();
    final alerts        = await _settingsService.getAlertsEnabled();
    final permitted     = await NotificationService.instance.hasPermission();

    if (mounted) {
      setState(() {
        _notificationsEnabled = notifications;
        _soundsEnabled        = sounds;
        _alertsEnabled        = alerts;
        _hasSystemPermission  = permitted;
        _isLoading            = false;
      });
    }
  }

  Future<void> _updateNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _settingsService.setNotificationsEnabled(value);

    // Si l'utilisateur active les notifications mais que la permission
    // système n'est pas accordée → demander la permission maintenant
    if (value && !_hasSystemPermission) {
      await _requestSystemPermission();
    }

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
    setState(() => _soundsEnabled = value);
    await _settingsService.setSoundsEnabled(value);
  }

  Future<void> _updateAlerts(bool value) async {
    setState(() => _alertsEnabled = value);
    await _settingsService.setAlertsEnabled(value);
  }

  /// Demande la permission système de notification.
  /// Appelée lorsque l'utilisateur active les notifications dans les paramètres.
  Future<void> _requestSystemPermission() async {
    if (_isRequestingPermission) return;

    setState(() => _isRequestingPermission = true);

    try {
      final granted = await NotificationService.instance.requestPermission();
      if (mounted) {
        setState(() {
          _hasSystemPermission  = granted;
          _isRequestingPermission = false;
        });

        if (granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission accordée — notifications activées'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Permission refusée → informer l'utilisateur
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                kIsWeb
                    ? 'Permission refusée par le navigateur. Activez les notifications dans les paramètres du site.'
                    : 'Permission refusée. Activez les notifications dans les paramètres système.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRequestingPermission = false);
      }
    }
  }


  /// Encart « notifications locales » — ce qui fonctionne réellement.
  ///
  /// Le mécanisme en service est la connexion Socket.IO : le serveur signale
  /// le message, l'application affiche une bannière (et une notification
  /// système quand elle est autorisée). Cela suppose l'application ouverte.
  ///
  /// Cet encart existe pour que la distinction avec les notifications à
  /// distance soit visible, et non seulement documentée dans le code :
  /// l'utilisateur doit pouvoir savoir à quoi s'attendre.
  Widget _buildEtatLocal() {
    final c = OmniCouleurs.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: c.surface,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.wifi_rounded, color: OmniPalette.succes, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Notifications locales (Socket.IO)',
                      style: OmniTypo.corpsGras.copyWith(color: c.texte),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Actives : vous êtes prévenu en temps réel dès qu’un message '
                'arrive, pendant que l’application est ouverte.',
                style: OmniTypo.secondaire.copyWith(color: c.texteSecondaire),
              ),
              const SizedBox(height: 8),
              Text(
                'Elles cessent dès que l’application est fermée — c’est le '
                'rôle des notifications à distance, distinctes.',
                style: OmniTypo.micro.copyWith(color: c.texteEstompe),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche le widget d'état de permission système.
  /// Encart d'état des notifications à distance.
  ///
  /// Volontairement explicite : plutôt que d'afficher un interrupteur qui ne
  /// commanderait rien, on indique où en est réellement le push et ce qu'il
  /// reste à faire.
  Widget _buildPushStatus() {
    final push = PushService.instance;
    final operationnel = push.operationnel && !push.enAttenteServeur;

    final (couleur, icone) = switch (push.etat) {
      EtatPush.jetonObtenu => push.enAttenteServeur
          ? (Colors.orange, Icons.hourglass_empty)
          : (Colors.green, Icons.cloud_done),
      EtatPush.configurationAbsente => (Colors.orange, Icons.cloud_off),
      EtatPush.permissionRefusee => (Colors.orange, Icons.notifications_off),
      EtatPush.erreur => (Colors.red, Icons.error_outline),
      EtatPush.nonTente => (Colors.grey, Icons.help_outline),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icone, color: couleur, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Notifications à distance (FCM / APNs)',
                      style: OmniTypo.corpsGras
                          .copyWith(color: OmniCouleurs.of(context).texte),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                push.resume(),
                style: TextStyle(color: Colors.grey[700]),
              ),
              if (!operationnel) ...[
                const SizedBox(height: 8),
                Text(
                  'Vous recevez les notifications pendant que '
                  'l’application est ouverte. Pour être prévenu lorsqu’elle '
                  'est fermée, la configuration Firebase et l’enregistrement '
                  'du jeton côté serveur sont nécessaires.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionStatus() {
    if (_hasSystemPermission) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700], size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Notifications système autorisées',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Permission non accordée
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications système non autorisées',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kIsWeb
                      ? 'Le navigateur doit autoriser les notifications pour ce site.'
                      : 'Accordez la permission dans les paramètres système Android.',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isRequestingPermission)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _requestSystemPermission,
              child: const Text('Autoriser', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
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
                // ── Header ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gérer les notifications',
                        style: OmniTypo.sousTitre
                            .copyWith(color: OmniCouleurs.of(context).texte),
                      ),
                      const SizedBox(height: OmniEspace.xs),
                      Text(
                        'Deux mécanismes distincts coexistent : les notifications '
                        'locales, actives pendant que l’application est ouverte, et '
                        'les notifications à distance, qui nécessitent un serveur.',
                        style: OmniTypo.secondaire.copyWith(
                          color: OmniCouleurs.of(context).texteSecondaire,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── État de la permission système ─────────────────
                _buildPermissionStatus(),
                const SizedBox(height: 16),

                // ── Notifications locales (Socket.IO) ────────────
                // Mécanisme réellement en service aujourd'hui : il fonctionne
                // grâce à la connexion Socket.IO, tant que l'application est
                // au premier plan.
                OmniApparitionEspacee(index: 0, child: _buildEtatLocal()),
                const SizedBox(height: 12),

                // ── État des notifications à distance (FCM / APNs) ──
                // Cet encart ne ment jamais sur l'état réel : tant que
                // Firebase n'est pas configuré ou que le serveur ne sait pas
                // enregistrer le jeton, c'est écrit ici noir sur blanc.
                OmniApparitionEspacee(index: 1, child: _buildPushStatus()),
                const SizedBox(height: 16),

                // ── Notifications (toggle principal) ──────────────
                SwitchListTile(
                  value: _notificationsEnabled,
                  onChanged: _updateNotifications,
                  title: const Text('Notifications de messages'),
                  subtitle: Text(
                    _notificationsEnabled
                        ? 'Activées — vous recevrez une notification à chaque nouveau message'
                        : 'Désactivées — aucune notification système',
                  ),
                  secondary: Icon(
                    _notificationsEnabled
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                  ),
                ),

                const Divider(),

                // ── Sons ──────────────────────────────────────────
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

                // ── Alertes ───────────────────────────────────────
                SwitchListTile(
                  value: _alertsEnabled,
                  onChanged: _updateAlerts,
                  title: const Text('Alertes in-app'),
                  subtitle: const Text(
                    'Afficher une bannière lorsque vous êtes dans l\'application',
                  ),
                  secondary: Icon(
                    _alertsEnabled
                        ? Icons.announcement
                        : Icons.announcement_outlined,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Info Card ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Comment fonctionnent les notifications',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '• Notification à chaque nouveau message reçu\n'
                            '• Pas de doublon pour le même message\n'
                            '• Pas de notification si vous regardez déjà la conversation\n'
                            '• Gratuit — aucun abonnement requis\n'
                            '• Cliquer sur la notification ouvre directement la conversation',
                            style: TextStyle(fontSize: 13, height: 1.6),
                          ),
                          if (kIsWeb) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Sur Web/PWA : les notifications sont affichées par le navigateur lorsque l\'application est ouverte.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Text(
                              'Sur Android : les notifications in-app sont affichées lorsque l\'application est au premier plan.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
