import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/messaging/conversation_screen.dart';
import '../screens/contacts/contacts_screen.dart';
import '../screens/groups/groups_screen.dart';
import '../screens/settings/statistics_screen.dart';
import '../screens/subscription_screen.dart';
import '../screens/settings/settings_screen.dart';
import 'web_sidebar.dart';
import 'responsive_layout.dart';

/// Main web layout with sidebar navigation
class WebMainLayout extends StatefulWidget {
  final Widget? child;
  
  const WebMainLayout({super.key, this.child});

  @override
  State<WebMainLayout> createState() => _WebMainLayoutState();
}

class _WebMainLayoutState extends State<WebMainLayout> {
  String _currentRoute = '/dashboard';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080c14),
      body: Row(
        children: [
          // Sidebar (only on desktop/tablet)
          if (MediaQuery.of(context).size.width >= 600)
            WebSidebar(
              currentRoute: _currentRoute,
              onRouteChanged: (route) {
                setState(() {
                  _currentRoute = route;
                });
              },
            ),
          
          // Main content
          Expanded(
            child: Column(
              children: [
                // Top header
                _buildHeader(context),
                
                // Content area
                Expanded(
                  child: widget.child ?? _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0f1520),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF6b7a96).withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Page title
          Text(
            _getPageTitle(_currentRoute),
            style: const TextStyle(
              color: Color(0xFFe8edf5),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // Connection status
          _buildConnectionStatus(),
          
          const SizedBox(width: 16),
          
          // User info on web
          if (MediaQuery.of(context).size.width >= 600 && user != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF080c14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00d4ff).withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF00d4ff),
                    child: Text(
                      (user.name?.isNotEmpty == true)
                          ? user.name![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name ?? 'Utilisateur',
                        style: const TextStyle(
                          color: Color(0xFFe8edf5),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00d4ff).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Premium',
                          style: TextStyle(
                            color: Color(0xFF00d4ff),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Mobile user menu
          if (MediaQuery.of(context).size.width < 600)
            PopupMenuButton<String>(
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF00d4ff).withOpacity(0.1),
                child: Text(
                  user?.name?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: Color(0xFF00d4ff),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              color: const Color(0xFF0f1520),
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF6b7a96)),
                      const SizedBox(width: 12),
                      Text(
                        user?.name ?? 'Utilisateur',
                        style: const TextStyle(color: Color(0xFFe8edf5)),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Color(0xFF6b7a96)),
                      SizedBox(width: 12),
                      Text(
                        'Paramètres',
                        style: TextStyle(color: Color(0xFFe8edf5)),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 12),
                      Text(
                        'Déconnexion',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'settings') {
                  setState(() {
                    _currentRoute = '/settings';
                  });
                } else if (value == 'logout') {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                }
              },
            ),
        ],
      ),
    );
  }
  
  Widget _buildConnectionStatus() {
    // TODO: Get real connection status from provider
    final isOnline = true;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline 
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isOnline ? 'En ligne' : 'Hors ligne',
            style: TextStyle(
              color: isOnline ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    switch (_currentRoute) {
      case '/dashboard':
        return const DashboardScreen();
      case '/messages':
        return ConversationScreen(contactId: '', contactName: 'Messages');
      case '/contacts':
        return const ContactsScreen();
      case '/groups':
        return const GroupsScreen();
      case '/statistics':
        return const StatisticsScreen();
      case '/subscription':
        return const SubscriptionScreen();
      case '/settings':
        return const SettingsScreen();
      default:
        return const DashboardScreen();
    }
  }
  
  String _getPageTitle(String route) {
    switch (route) {
      case '/dashboard':
        return 'Tableau de bord';
      case '/messages':
        return 'Messages';
      case '/contacts':
        return 'Contacts';
      case '/groups':
        return 'Groupes';
      case '/statistics':
        return 'Statistiques';
      case '/subscription':
        return 'Abonnement';
      case '/settings':
        return 'Paramètres';
      default:
        return 'OmniSMS';
    }
  }
}
