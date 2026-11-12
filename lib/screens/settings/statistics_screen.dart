import 'package:flutter/material.dart';
import '../../theme/omni_design.dart';
import '../../services/settings_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final SettingsService _settingsService = SettingsService();
  
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _settingsService.getStatistics();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur lors du chargement des statistiques';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: OmniPalette.erreur,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStatistics,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStatistics,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Votre activité',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Statistiques de votre utilisation',
                              style: TextStyle(
                                color: OmniCouleurs.of(context).texteSecondaire,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats Cards
                      _buildStatCard(
                        context,
                        title: 'Messages envoyés',
                        value: _stats?['messagesSent']?.toString() ?? '0',
                        icon: Icons.send,
                        color: OmniPalette.info,
                      ),
                      const SizedBox(height: 12),

                      _buildStatCard(
                        context,
                        title: 'Messages reçus',
                        value: _stats?['messagesReceived']?.toString() ?? '0',
                        icon: Icons.inbox,
                        color: OmniPalette.succes,
                      ),
                      const SizedBox(height: 12),

                      _buildStatCard(
                        context,
                        title: 'Contacts',
                        value: _stats?['totalContacts']?.toString() ?? '0',
                        icon: Icons.contacts,
                        color: OmniPalette.avertissement,
                      ),
                      const SizedBox(height: 12),

                      _buildStatCard(
                        context,
                        title: 'Groupes actifs',
                        value: _stats?['activeGroups']?.toString() ?? '0',
                        icon: Icons.group,
                        color: OmniPalette.bleu,
                      ),
                      const SizedBox(height: 24),

                      // Additional Info
                      Card(
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
                                  Text(
                                    'Informations',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Les statistiques sont mises à jour en temps réel depuis le serveur.',
                                style: TextStyle(
                                  color: OmniCouleurs.of(context).texteSecondaire,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tirez vers le bas pour actualiser.',
                                style: TextStyle(
                                  color: OmniCouleurs.of(context).texteSecondaire,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
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
                      fontSize: 14,
                      color: OmniCouleurs.of(context).texteSecondaire,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
