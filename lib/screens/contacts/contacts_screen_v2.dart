import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contacts_provider_v2.dart';
import '../../models/models.dart';
import '../messaging/conversation_screen.dart';

class ContactsScreenV2 extends StatefulWidget {
  const ContactsScreenV2({super.key});

  @override
  State<ContactsScreenV2> createState() => _ContactsScreenV2State();
}

class _ContactsScreenV2State extends State<ContactsScreenV2> {
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _initializeContacts();
  }

  Future<void> _initializeContacts() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ContactsProviderV2>();
      
      // Check permission status first
      await provider.checkPermissionStatus();
      
      if (!provider.hasPermission) {
        // Show permission request dialog
        _showPermissionDialog();
      } else if (provider.contacts.isEmpty) {
        // Load contacts if permission already granted
        await provider.loadContacts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showPermissionDialog() async {
    if (!mounted) return;
    
    final provider = context.read<ContactsProviderV2>();
    
    if (provider.isPermissionPermanentlyDenied) {
      // Show settings dialog
      _showSettingsDialog();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.contacts,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Accès aux contacts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OmniSMS a besoin d\'accéder à vos contacts pour :',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 12),
            _PermissionReasonItem(
              icon: Icons.message,
              text: 'Envoyer des messages à vos contacts',
            ),
            _PermissionReasonItem(
              icon: Icons.group,
              text: 'Trouver vos amis sur OmniSMS',
            ),
            _PermissionReasonItem(
              icon: Icons.sync,
              text: 'Synchroniser votre carnet d\'adresses',
            ),
            SizedBox(height: 12),
            Text(
              'Vos contacts restent privés et sécurisés.',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Pas maintenant',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Autoriser'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await provider.requestPermission();
    }
  }

  Future<void> _showSettingsDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.settings,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Permission requise',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'L\'accès aux contacts a été refusé. '
          'Veuillez activer la permission dans les paramètres de votre appareil pour utiliser cette fonctionnalité.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ContactsProviderV2>().openSettings();
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Ouvrir paramètres'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text(
          'Contacts',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          Consumer<ContactsProviderV2>(
            builder: (context, provider, _) {
              if (!provider.hasPermission) return const SizedBox.shrink();
              
              return IconButton(
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                onPressed: provider.isLoading 
                    ? null 
                    : () => provider.refreshContacts(),
                tooltip: 'Actualiser',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<ContactsProviderV2>(
        builder: (context, provider, _) {
          // Permission denied states
          if (provider.loadingState == ContactsLoadingState.permissionDenied ||
              provider.loadingState == ContactsLoadingState.permissionPermanentlyDenied) {
            return _buildPermissionDeniedView(provider);
          }

          // Initial or loading state
          if (provider.loadingState == ContactsLoadingState.initial ||
              (provider.isLoading && provider.contacts.isEmpty)) {
            return _buildLoadingView();
          }

          // Error state
          if (provider.hasError && provider.contacts.isEmpty) {
            return _buildErrorView(provider);
          }

          // Empty state
          if (provider.contacts.isEmpty && !provider.isLoading) {
            return _buildEmptyView();
          }

          // Contacts list
          return Column(
            children: [
              // Search bar
              _buildSearchBar(provider),
              // Contacts list
              Expanded(
                child: _buildContactsList(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPermissionDeniedView(ContactsProviderV2 provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                provider.isPermissionPermanentlyDenied
                    ? Icons.block_rounded
                    : Icons.contacts_outlined,
                size: 80,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              provider.isPermissionPermanentlyDenied
                  ? 'Permission refusée'
                  : 'Permission requise',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              provider.isPermissionPermanentlyDenied
                  ? 'L\'accès aux contacts a été refusé. Veuillez l\'activer dans les paramètres.'
                  : 'OmniSMS a besoin d\'accéder à vos contacts pour afficher votre liste de contacts.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                if (provider.isPermissionPermanentlyDenied) {
                  provider.openSettings();
                } else {
                  _showPermissionDialog();
                }
              },
              icon: Icon(
                provider.isPermissionPermanentlyDenied
                    ? Icons.settings
                    : Icons.check_circle_outline,
              ),
              label: Text(
                provider.isPermissionPermanentlyDenied
                    ? 'Ouvrir paramètres'
                    : 'Autoriser l\'accès',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
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
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Chargement des contacts...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ContactsProviderV2 provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            const Text(
              'Erreur',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ?? 'Une erreur est survenue',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => provider.refreshContacts(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
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
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contacts_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun contact',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun contact trouvé sur votre appareil',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ContactsProviderV2 provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un contact...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    provider.clearSearch();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          provider.searchContacts(value);
        },
      ),
    );
  }

  Widget _buildContactsList(ContactsProviderV2 provider) {
    final contacts = provider.contacts;
    
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _buildContactTile(contact);
      },
    );
  }

  Widget _buildContactTile(ContactModel contact) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Text(
          contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      title: Text(
        contact.name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        contact.phone ?? '',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Icons.message_rounded,
        color: Theme.of(context).primaryColor,
        size: 20,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationScreen(
              contactId: contact.phone ?? '', // Using phone as contactId
              contactName: contact.name,
            ),
          ),
        );
      },
    );
  }
}

class _PermissionReasonItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PermissionReasonItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
