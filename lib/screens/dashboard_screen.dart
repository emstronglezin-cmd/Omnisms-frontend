import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../screens/settings/settings_screen.dart';
import '../screens/contacts/contacts_screen_v2.dart' as contact_screen;
import '../screens/groups/groups_screen.dart' as group_screen;
import '../screens/messaging/conversation_screen.dart' as msg_screen;
import '../screens/groups/create_group_screen.dart';
import '../screens/transcription_screen.dart';
import '../layouts/responsive_layout.dart';
import '../layouts/web_main_layout.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DashboardHomePage(),
      const contact_screen.ContactsScreenV2(),
      const group_screen.GroupsScreen(),
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use responsive layout for web
    if (kIsWeb && MediaQuery.of(context).size.width >= 600) {
      return const WebMainLayout();
    }

    // Mobile layout with bottom navigation
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Groupes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}

class DashboardHomePage extends StatelessWidget {
  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb && MediaQuery.of(context).size.width >= 600;
    
    return Scaffold(
      backgroundColor: isWeb ? const Color(0xFF080c14) : null,
      body: CustomScrollView(
        slivers: [
          if (!isWeb)
            const SliverAppBar.large(
              title: Text('OmniSMS'),
              centerTitle: true,
              floating: true,
              snap: true,
            ),
          SliverPadding(
            padding: EdgeInsets.all(isWeb ? 32 : 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Welcome Card
                Card(
                  elevation: isWeb ? 2 : 1,
                  color: isWeb ? const Color(0xFF0f1520) : null,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isWeb 
                          ? [const Color(0xFF00d4ff), const Color(0xFF0066ff)]
                          : [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue sur OmniSMS',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Messagerie sécurisée et moderne',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                        if (isWeb) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Abonnement Premium actif',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (isWeb && constraints.maxWidth > 800) {
                      // 4 columns on web
                      return Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Crédits SMS',
                              '1,250',
                              Icons.credit_card,
                              const Color(0xFF00d4ff),
                              isWeb,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Envoyés',
                              '84',
                              Icons.send,
                              const Color(0xFF0066ff),
                              isWeb,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Contacts',
                              '32',
                              Icons.contacts,
                              Colors.green,
                              isWeb,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              'Groupes',
                              '5',
                              Icons.group,
                              Colors.orange,
                              isWeb,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // 2 columns on mobile
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Messages',
                                  '0',
                                  Icons.message,
                                  Colors.blue,
                                  isWeb,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Contacts',
                                  '0',
                                  Icons.contacts,
                                  Colors.green,
                                  isWeb,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Quick Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Actions rapides',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isWeb ? const Color(0xFFe8edf5) : null,
                      ),
                    ),
                    if (isWeb)
                      TextButton.icon(
                        onPressed: () {
                          // Navigate to subscription
                        },
                        icon: const Icon(Icons.credit_card, size: 16),
                        label: const Text('Recharger'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00d4ff),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                _buildQuickAction(
                  context,
                  'Nouveau message',
                  Icons.add_comment,
                  const Color(0xFF00d4ff),
                  isWeb,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const msg_screen.ConversationScreen(
                          contactId: '',
                          contactName: 'Nouveau message',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                _buildQuickAction(
                  context,
                  'Créer un groupe',
                  Icons.group_add,
                  const Color(0xFF0066ff),
                  isWeb,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateGroupScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                _buildQuickAction(
                  context,
                  'Transcription vocale',
                  Icons.mic,
                  Colors.orange,
                  isWeb,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TranscriptionScreen(),
                      ),
                    );
                  },
                ),

                if (isWeb) ...[
                  const SizedBox(height: 32),
                  // Subscription banner for web
                  Card(
                    color: const Color(0xFF0f1520),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF00d4ff).withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00d4ff).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.workspace_premium,
                              color: Color(0xFF00d4ff),
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Abonnement Premium',
                                  style: TextStyle(
                                    color: Color(0xFFe8edf5),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '2000 FCFA / mois - SMS illimités',
                                  style: TextStyle(
                                    color: const Color(0xFF6b7a96),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Open payment link
                            },
                            icon: const Icon(Icons.shopping_cart),
                            label: const Text('S\'abonner'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00d4ff),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    bool isWeb,
  ) {
    return Card(
      elevation: isWeb ? 2 : 1,
      color: isWeb ? const Color(0xFF0f1520) : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: isWeb
            ? BoxDecoration(
                border: Border.all(
                  color: color.withOpacity(0.2),
                ),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: isWeb ? 32 : 28,
                ),
                if (isWeb)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '↑ 12%',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: isWeb ? 28 : 24,
                fontWeight: FontWeight.bold,
                color: isWeb ? const Color(0xFFe8edf5) : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
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
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    bool isWeb,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: isWeb ? 1 : 0,
      color: isWeb ? const Color(0xFF0f1520) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: isWeb
              ? BoxDecoration(
                  border: Border.all(
                    color: color.withOpacity(0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isWeb ? const Color(0xFFe8edf5) : null,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isWeb ? const Color(0xFF6b7a96) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
