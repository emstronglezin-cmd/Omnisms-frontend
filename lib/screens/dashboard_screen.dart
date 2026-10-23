import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'contacts/contacts_screen_v2.dart';
import 'groups/groups_screen.dart';
import 'settings/settings_screen.dart';
import 'messaging/conversation_screen.dart';
import 'messaging/messages_list_page.dart';
import 'groups/create_group_screen.dart';
import 'transcription_screen.dart';
import 'subscription_screen.dart';
import 'settings/statistics_screen.dart';

/// ─── MAIN DASHBOARD SCREEN ───────────────────────────────────────────────────
/// Single source of truth for the dashboard.
/// On web (wide): shows sidebar + content.
/// On mobile: shows bottom nav bar.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Messages'),
    _NavItem(icon: Icons.contacts_outlined, activeIcon: Icons.contacts, label: 'Contacts'),
    _NavItem(icon: Icons.group_outlined, activeIcon: Icons.group, label: 'Groupes'),
    _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Paramètres'),
  ];

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const MessagesListPage();
      case 1:
        return const ContactsScreenV2();
      case 2:
        return const GroupsScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const MessagesListPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = kIsWeb && MediaQuery.of(context).size.width >= 768;

    if (isWideScreen) {
      return _buildWebLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    // CORRECTION safe-area (Session 9) — étendue à iOS natif :
    // - Safari iPhone (PWA) : la barre du navigateur chevauche le bas de
    //   l'interface ; Flutter web ne gère pas env(safe-area-inset-bottom).
    // - iOS natif : l'indicateur d'accueil (barre horizontale en bas des
    //   iPhone sans bouton) recouvre la barre de navigation et capte une
    //   partie des appuis. MediaQuery.viewPadding.bottom vaut alors ~34 pt.
    // - Android : cette valeur est nulle en navigation 3 boutons comme en
    //   navigation gestuelle → aucun changement visuel.
    // La valeur est appliquée uniquement si elle est non nulle, donc sans
    // effet sur les appareils qui n'en ont pas besoin.
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(4, _buildPage),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            elevation: 8,
            destinations: _navItems.map((item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: item.label,
            )).toList(),
          ),
          // Padding safe-area pour Safari iPhone (browser chrome en bas)
          if (bottomPadding > 0)
            SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

  Widget _buildWebLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF080c14),
      body: Row(
        children: [
          // Sidebar
          _WebSidebarWidget(
            selectedIndex: _selectedIndex,
            navItems: _navItems,
            onSelect: (i) => setState(() => _selectedIndex = i),
          ),
          // Content
          Expanded(
            child: Column(
              children: [
                _WebHeaderWidget(selectedIndex: _selectedIndex, navItems: _navItems),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: List.generate(4, _buildPage),
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

// ─── Nav Item data class ──────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

// ─── Web Sidebar ──────────────────────────────────────────────────────────────
class _WebSidebarWidget extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;
  final ValueChanged<int> onSelect;

  const _WebSidebarWidget({
    required this.selectedIndex,
    required this.navItems,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFF0f1520),
      child: Column(
        children: [
          // Logo
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF0066FF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sms_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'OmniSMS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          // Nav items
          ...List.generate(navItems.length, (i) {
            final item = navItems[i];
            final isSelected = selectedIndex == i;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00D4FF).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3))
                    : null,
              ),
              child: ListTile(
                leading: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected
                      ? const Color(0xFF00D4FF)
                      : const Color(0xFF6b7a96),
                  size: 22,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFe8edf5)
                        : const Color(0xFF6b7a96),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                onTap: () => onSelect(i),
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }),
          const Spacer(),
          // Logout button
          Consumer<AuthProvider>(
            builder: (ctx, auth, _) => Container(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red, size: 20),
                title: const Text(
                  'Déconnexion',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
                onTap: () async {
                  await auth.logout();
                  if (ctx.mounted) {
                    Navigator.of(ctx).pushReplacementNamed('/login');
                  }
                },
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Web Header ───────────────────────────────────────────────────────────────
class _WebHeaderWidget extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;

  const _WebHeaderWidget({
    required this.selectedIndex,
    required this.navItems,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (ctx, auth, _) {
        final user = auth.currentUser;
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: const Color(0xFF0f1520),
          child: Row(
            children: [
              Text(
                navItems[selectedIndex].label,
                style: const TextStyle(
                  color: Color(0xFFe8edf5),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Online dot
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('En ligne',
                        style: TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                ),
              ),
              if (user != null) ...[
                const SizedBox(width: 16),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF00D4FF),
                  child: Text(
                    user.name?.isNotEmpty == true
                        ? user.name![0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  user.name ?? 'Utilisateur',
                  style: const TextStyle(
                    color: Color(0xFFe8edf5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── DASHBOARD HOME PAGE ──────────────────────────────────────────────────────
class DashboardHomePage extends StatelessWidget {
  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb && MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: isWeb ? const Color(0xFF080c14) : null,
      appBar: isWeb
          ? null
          : AppBar(
              title: const Text('OmniSMS'),
              centerTitle: true,
            ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWeb ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            _buildWelcomeCard(context, isWeb),
            const SizedBox(height: 24),

            // Stats
            _buildStatsRow(context, isWeb),
            const SizedBox(height: 24),

            // Quick actions title
            Text(
              'Actions rapides',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isWeb ? const Color(0xFFe8edf5) : null,
                  ),
            ),
            const SizedBox(height: 16),

            // Quick actions
            _buildQuickAction(
              context, 'Nouveau message', Icons.add_comment,
              const Color(0xFF00D4FF), isWeb,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConversationScreen(
                    conversationId: 'new',
                    contactId: 'new',
                    contactName: 'Nouveau message',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickAction(
              context, 'Créer un groupe', Icons.group_add,
              const Color(0xFF0066FF), isWeb,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickAction(
              context, 'Transcription vocale', Icons.mic,
              Colors.orange, isWeb,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TranscriptionScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickAction(
              context, 'Statistiques', Icons.bar_chart,
              Colors.purple, isWeb,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildQuickAction(
              context, 'Abonnement', Icons.workspace_premium,
              const Color(0xFFFFD700), isWeb,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, bool isWeb) {
    return Consumer<AuthProvider>(
      builder: (ctx, auth, _) => Card(
        elevation: 2,
        color: isWeb ? const Color(0xFF0f1520) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00D4FF), Color(0xFF0066FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bienvenue${auth.currentUser?.name != null ? ", ${auth.currentUser!.name}" : ""} 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'OmniSMS — Messagerie sécurisée et moderne',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, bool isWeb) {
    final stats = [
      ('Messages', '0', Icons.message, Colors.blue),
      ('Contacts', '0', Icons.contacts, Colors.green),
      ('Groupes', '0', Icons.group, Colors.orange),
      ('Crédits', '0', Icons.credit_card, const Color(0xFF00D4FF)),
    ];

    if (isWeb) {
      return Row(
        children: stats
            .map((s) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _buildStatCard(context, s.$1, s.$2, s.$3, s.$4, isWeb),
                  ),
                ))
            .toList(),
      );
    }

    return Row(
      children: [
        Expanded(child: _buildStatCard(context, stats[0].$1, stats[0].$2, stats[0].$3, stats[0].$4, isWeb)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(context, stats[1].$1, stats[1].$2, stats[1].$3, stats[1].$4, isWeb)),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color, bool isWeb) {
    return Card(
      color: isWeb ? const Color(0xFF0f1520) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isWeb ? const Color(0xFFe8edf5) : null,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isWeb ? const Color(0xFF6b7a96) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String title, IconData icon,
      Color color, bool isWeb, VoidCallback onTap) {
    return Card(
      color: isWeb ? const Color(0xFF0f1520) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isWeb ? const Color(0xFFe8edf5) : null,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: isWeb ? const Color(0xFF6b7a96) : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
