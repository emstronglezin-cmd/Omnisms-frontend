import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contacts_provider_v2.dart';
import '../../providers/messaging_provider.dart';
import '../../models/models.dart';
import '../messaging/conversation_screen.dart';
import '../../services/auth_service.dart';

/// ContactsScreenV2 — Écran des contacts avec import et ajout
///
/// Fonctionnalités :
///   - Chargement automatique depuis le backend au premier lancement
///   - Demande de permission contacts (iOS/Android)
///   - Bouton "+ Ajouter un contact" (POST /api/contacts/add)
///   - Recherche locale
///   - Ouvrir une conversation depuis un contact
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Initialisation au premier lancement ──────────────────────
  Future<void> _initializeContacts() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<ContactsProviderV2>();

      await provider.checkPermissionStatus();

      if (!provider.hasPermission) {
        _showPermissionDialog();
      } else {
        // Permission OK → charger les contacts
        await provider.loadContacts();
      }
    });
  }

  // ── Dialogue permission contacts ─────────────────────────────
  Future<void> _showPermissionDialog() async {
    if (!mounted) return;
    final provider = context.read<ContactsProviderV2>();

    if (provider.isPermissionPermanentlyDenied) {
      _showSettingsDialog();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(ctx).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.contacts,
                  color: Theme.of(ctx).primaryColor, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Accès aux contacts',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                text: 'Envoyer des messages à vos contacts'),
            _PermissionReasonItem(
                icon: Icons.group,
                text: 'Trouver vos amis sur OmniSMS'),
            _PermissionReasonItem(
                icon: Icons.sync,
                text: 'Synchroniser votre carnet d\'adresses'),
            SizedBox(height: 12),
            Text(
              'Vos contacts restent privés et sécurisés.',
              style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Pas maintenant',
                style: TextStyle(color: Colors.grey[600])),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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

  // ── Dialogue paramètres (permission permanente refusée) ───────
  Future<void> _showSettingsDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.settings,
                color: Theme.of(ctx).primaryColor, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Permission requise',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          'L\'accès aux contacts a été refusé. '
          'Veuillez l\'activer dans les paramètres de votre appareil.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ContactsProviderV2>().openSettings();
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ouvrir paramètres'),
          ),
        ],
      ),
    );
  }

  // ── Dialogue Ajouter un contact ───────────────────────────────
  Future<void> _showAddContactDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, size: 28),
            SizedBox(width: 12),
            Text('Ajouter un contact',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nom
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nom complet *',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Le nom est requis';
                  }
                  if (v.trim().length > 60) {
                    return 'Nom trop long (max 60 caractères)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Téléphone
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone *',
                  hintText: '+22670000000',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  helperText: 'Format international : +226XXXXXXXX',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Le numéro est requis';
                  }
                  final cleaned = v.replaceAll(RegExp(r'[^\d+]'), '');
                  if (cleaned.length < 8) {
                    return 'Numéro trop court (min 8 chiffres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Le contact sera ajouté à votre liste. '
                'S\'il a un compte OmniSMS, vous pourrez lui envoyer des messages.',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: TextStyle(color: Colors.grey[600])),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _doAddContact(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
      );
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
  }

  // ── Effectuer l'ajout du contact ─────────────────────────────
  Future<void> _doAddContact({
    required String name,
    required String phone,
  }) async {
    if (!mounted) return;

    final provider = context.read<ContactsProviderV2>();
    final addResult = await provider.addContact(name: name, phone: phone);

    if (!mounted) return;

    if (addResult['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  addResult['message'] ?? 'Contact ajouté avec succès !',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  addResult['error'] ?? 'Erreur lors de l\'ajout du contact.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Réessayer',
            textColor: Colors.white,
            onPressed: () =>
                _doAddContact(name: name, phone: phone),
          ),
        ),
      );
    }
  }

  // ── Importer le carnet d'adresses du téléphone ───────────────
  /// Lit les contacts de l'appareil (flutter_contacts) puis les envoie à
  /// POST /api/contacts/sync { contacts, country: 'BF' }.
  Future<void> _importDeviceContacts() async {
    final provider = context.read<ContactsProviderV2>();
    if (provider.isImportingDeviceContacts) return;

    final messenger = ScaffoldMessenger.of(context);

    // Bandeau de progression pendant la lecture + la synchronisation.
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 6),
        behavior: SnackBarBehavior.floating,
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Import de vos contacts…')),
          ],
        ),
      ),
    );

    final result = await provider.importDeviceContacts();

    messenger.hideCurrentSnackBar();
    if (!mounted) return;

    final success = result['success'] == true;
    final message = (result['message'] ?? result['error'] ?? '').toString();

    // Permission refusée définitivement → proposer d'ouvrir les réglages.
    if (!success && result['permanentlyDenied'] == true) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Accès aux contacts'),
          content: const Text(
            "OmniSMS n'a pas accès à vos contacts. Autorisez l'accès dans les "
            "réglages de l'appareil pour importer votre carnet d'adresses.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Plus tard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Ouvrir les réglages'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await provider.openSystemSettings();
      }
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.isEmpty
                    ? (success
                        ? 'Contacts importés'
                        : "Import impossible.")
                    : message,
              ),
            ),
          ],
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: success ? 4 : 6),
      ),
    );
  }

  // ── Importer depuis Google ───────────────────────────────────
  /// Déclenche le flux backend : autorisation Google → consentement →
  /// import → rechargement de la liste.
  Future<void> _importFromGoogle() async {
    final provider = context.read<ContactsProviderV2>();
    if (provider.isImportingFromGoogle) return;

    // Capturé avant les await (le contexte peut être démonté entre-temps).
    final messenger = ScaffoldMessenger.of(context);

    // Bandeau de progression : « Connexion à Google… » puis
    // « Importation des contacts… » (suit l'état du provider).
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 6),
        behavior: SnackBarBehavior.floating,
        content: Consumer<ContactsProviderV2>(
          builder: (_, p, __) => Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.googleImportLabel.isEmpty
                      ? 'Connexion à Google…'
                      : p.googleImportLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final result = await provider.importFromGoogle();

    messenger.hideCurrentSnackBar();
    if (!mounted) return;

    final success = result['success'] == true;
    final baseMessage = success
        ? (provider.googleImportMessage ?? 'Contacts importés')
        : (provider.googleImportMessage ??
            'Impossible d\'importer les contacts Google.');
    final detail = success ? provider.googleImportDetail : '';
    final message = detail.isEmpty ? baseMessage : '$baseMessage — $detail';

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: success ? 4 : 6),
        action: success
            ? null
            : SnackBarAction(
                label: 'Réessayer',
                textColor: Colors.white,
                onPressed: _importFromGoogle,
              ),
      ),
    );

    provider.resetGoogleImport();
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
          // Bouton Synchroniser
          Consumer<ContactsProviderV2>(
            builder: (ctx, provider, _) {
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
          const SizedBox(width: 4),
          // Menu d'actions (import Google)
          Consumer<ContactsProviderV2>(
            builder: (ctx, provider, _) => PopupMenuButton<String>(
              tooltip: 'Plus d\'options',
              enabled: !provider.isImportingFromGoogle,
              icon: provider.isImportingFromGoogle
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'google') _importFromGoogle();
                if (value == 'device') _importDeviceContacts();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem<String>(
                  value: 'device',
                  child: ListTile(
                    leading: Icon(Icons.contacts_rounded),
                    title: Text('Importer mes contacts'),
                    subtitle: Text('Carnet du téléphone'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'google',
                  child: ListTile(
                    leading: Icon(Icons.cloud_download_rounded),
                    title: Text('Importer depuis Google'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // ── FAB Ajouter un contact ────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContactDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Ajouter'),
        tooltip: 'Ajouter un contact',
      ),
      body: Consumer<ContactsProviderV2>(
        builder: (ctx, provider, _) {
          // État permission refusée
          if (provider.loadingState ==
                  ContactsLoadingState.permissionDenied ||
              provider.loadingState ==
                  ContactsLoadingState.permissionPermanentlyDenied) {
            return _buildPermissionDeniedView(provider);
          }

          // Chargement initial
          if (provider.loadingState == ContactsLoadingState.initial ||
              (provider.isLoading && provider.contacts.isEmpty)) {
            return _buildLoadingView();
          }

          // Erreur
          if (provider.hasError && provider.contacts.isEmpty) {
            return _buildErrorView(provider);
          }

          // Liste vide
          if (provider.contacts.isEmpty && !provider.isLoading) {
            return _buildEmptyView();
          }

          // Liste de contacts
          return Column(
            children: [
              _buildSearchBar(provider),
              if (provider.isLoading)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _buildContactsList(provider)),
            ],
          );
        },
      ),
    );
  }

  // ── Vues d'état ───────────────────────────────────────────────

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
                  fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              provider.isPermissionPermanentlyDenied
                  ? 'Activez l\'accès aux contacts dans les paramètres.'
                  : 'OmniSMS a besoin d\'accéder à vos contacts.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => provider.isPermissionPermanentlyDenied
                  ? provider.openSettings()
                  : _showPermissionDialog(),
              icon: Icon(provider.isPermissionPermanentlyDenied
                  ? Icons.settings
                  : Icons.check_circle_outline),
              label: Text(provider.isPermissionPermanentlyDenied
                  ? 'Ouvrir paramètres'
                  : 'Autoriser l\'accès'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Chargement des contacts...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
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
            Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
            const SizedBox(height: 24),
            const Text('Erreur',
                style:
                    TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ?? 'Une erreur est survenue',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => provider.refreshContacts(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
            Icon(Icons.contacts_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'Aucun contact',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Ajoutez votre premier contact en cliquant sur le bouton + ci-dessous.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Ajouter un contact'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            // Import du carnet du téléphone (même action que le menu AppBar)
            Consumer<ContactsProviderV2>(
              builder: (ctx, provider, _) => OutlinedButton.icon(
                onPressed: provider.isImportingDeviceContacts
                    ? null
                    : _importDeviceContacts,
                icon: provider.isImportingDeviceContacts
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.contacts_rounded),
                label: const Text('Importer mes contacts'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Import Google (même action que le menu de l'AppBar)
            Consumer<ContactsProviderV2>(
              builder: (ctx, provider, _) => OutlinedButton.icon(
                onPressed:
                    provider.isImportingFromGoogle ? null : _importFromGoogle,
                icon: provider.isImportingFromGoogle
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_rounded),
                label: const Text('Importer depuis Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
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
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {}); // pour afficher/masquer le bouton clear
          provider.searchContacts(value);
        },
      ),
    );
  }

  Widget _buildContactsList(ContactsProviderV2 provider) {
    final contacts = provider.contacts;

    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (ctx, index) {
        final contact = contacts[index];
        return _buildContactTile(contact);
      },
    );
  }

  // ── Open or create a conversation for this contact ───────────
  Future<void> _openContactConversation(
      BuildContext context, ContactModel contact) async {
    final authService = AuthService();
    final currentUserId = await authService.getUserId() ?? '';
    final contactId = contact.id.isNotEmpty ? contact.id : (contact.phone ?? '');

    if (!mounted) return;

    // Build conversationId: sorted UIDs joined with dash (mirrors backend logic)
    String conversationId;
    if (currentUserId.isNotEmpty && contactId.isNotEmpty) {
      final parts = [currentUserId, contactId]..sort();
      conversationId = parts.join('-');
    } else {
      conversationId = contactId;
    }

    // Add a placeholder conversation to MessagesListPage immediately
    final messaging = context.read<MessagingProvider>();
    messaging.addOrUpdateConversation(
      ConversationModel(
        id: conversationId,
        otherUserId: contactId,
        otherUserName: contact.name,
        otherUserPhotoUrl: contact.photoUrl,
        lastMessage: null,
        lastMessageTime: null,
        unreadCount: 0,
        isGroup: false,
      ),
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          conversationId: conversationId,
          contactId: contactId,
          contactName: contact.name,
          contactImageUrl: contact.photoUrl,
        ),
      ),
    );
  }

  Widget _buildContactTile(ContactModel contact) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            Theme.of(context).primaryColor.withOpacity(0.1),
        child: Text(
          contact.name.isNotEmpty
              ? contact.name[0].toUpperCase()
              : '?',
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
            fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        contact.phone ?? '',
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Statut OmniSMS : fourni par le backend (contacts manuels, VCF
          // et Google sont dans la même liste).
          if (contact.isRegistered)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'OmniSMS',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Externe',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            Icons.message_rounded,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
        ],
      ),
      onTap: () => _openContactConversation(context, contact),
    );
  }
}

// ── Widget utilitaire ─────────────────────────────────────────
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
            child: Icon(icon,
                size: 18, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
