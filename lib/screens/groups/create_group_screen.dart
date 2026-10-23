import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contacts_provider_v2.dart';
import '../../providers/groups_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../models/models.dart';
import 'group_conversation_screen.dart';
import '../../widgets/common/avatar_image.dart';

/// CreateGroupScreen — create a new group and immediately open its conversation.
///
/// Uses ContactsProviderV2 (updated) instead of the old ContactsProvider.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  /// Membres sélectionnés : clé d'identification du contact → identifiant
  /// de membre (UID) transmis au backend.
  ///
  /// Pourquoi une Map et plus un `Set<String>` d'`id` : `GET /api/contacts`
  /// ne renvoie PAS de champ `id` (uniquement `phone`, `name`, `avatar`,
  /// `isOnOmniSms`, `userId`, `registeredUserId`). `ContactModel.id` valait
  /// donc `''` pour tous les contacts synchronisés → le Set ne contenait
  /// qu'un seul élément partagé par toutes les lignes : un appui cochait
  /// visuellement toute la liste (bug signalé).
  final Map<String, String> _selectedMembers = {};
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ContactsProviderV2>();
      if (provider.contacts.isEmpty) {
        provider.loadContacts();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un nom de groupe')),
      );
      return;
    }

    // Group can be created without members (creator-only)
    setState(() => _isCreating = true);

    final groupsProvider = context.read<GroupsProvider>();
    final group = await groupsProvider.createGroupAndReturn(
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      // Uniquement les contacts réellement sélectionnés, dédupliqués.
      memberIds: _selectedMembers.values.toSet().toList(),
    );

    if (!mounted) return;

    setState(() => _isCreating = false);

    if (group != null) {
      // Add group conversation to MessagesListPage
      final messaging = context.read<MessagingProvider>();
      messaging.addOrUpdateConversation(
        ConversationModel(
          id: group.id,
          otherUserId: group.id,
          otherUserName: group.name,
          lastMessage: null,
          lastMessageTime: group.createdAt,
          unreadCount: 0,
          isGroup: true,
          groupName: group.name,
        ),
      );

      // Navigate: replace CreateGroupScreen with GroupConversationScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupConversationScreen(
            groupId: group.id,
            groupName: group.name,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Échec de la création du groupe'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un groupe'),
        actions: [
          if (_isCreating)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _createGroup,
              child: const Text('Créer'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Group info section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Group avatar placeholder
                CircleAvatar(
                  radius: 40,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.group,
                    size: 40,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),

                // Group name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du groupe *',
                    hintText: 'Ex: Famille, Travail...',
                    border: OutlineInputBorder(),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Group description (optional)
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnel)',
                    hintText: 'Décrivez le groupe...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),

          const Divider(),

          // Selected count
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  'Membres sélectionnés: ${_selectedMembers.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '(optionnel)',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Contacts list
          Expanded(
            child: Consumer<ContactsProviderV2>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.contacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.contacts_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucun contact disponible',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => provider.loadContacts(),
                          child: const Text('Charger les contacts'),
                        ),
                      ],
                    ),
                  );
                }

                // Une ligne = une clé distincte (`selectionKey` : UID, sinon
                // numéro, sinon nom). Les doublons sont retirés ici pour
                // qu'une même personne ne soit ni affichée ni comptée deux
                // fois, même si le backend la renvoie plusieurs fois.
                final contacts = _deduplicate(provider.contacts);

                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final key = contact.selectionKey;
                    final isSelected = _selectedMembers.containsKey(key);
                    // Sans compte OmniSMS il n'y a pas d'UID à transmettre :
                    // la ligne reste affichée mais n'est pas sélectionnable
                    // (plutôt que de créer un membre fantôme côté serveur).
                    final canBeMember = contact.memberId != null;
                    final phoneLabel = contact.phone ?? 'Pas de numéro';

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: canBeMember
                          ? (value) {
                              setState(() {
                                if (value == true) {
                                  final memberId = contact.memberId;
                                  if (memberId != null) {
                                    _selectedMembers[key] = memberId;
                                  }
                                } else {
                                  _selectedMembers.remove(key);
                                }
                              });
                            }
                          : null,
                      title: Text(contact.name),
                      subtitle: Text(
                        canBeMember
                            ? phoneLabel
                            : '$phoneLabel - sans compte OmniSMS',
                      ),
                      secondary: CircleAvatar(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: UserAvatar(
                          imageUrl: contact.photoUrl,
                          name: contact.name,
                          size: 40,
                          fallback: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Retire les contacts en doublon (même `selectionKey`).
  /// Un même contact peut arriver à la fois du carnet et de Google : sans ce
  /// filtre, la liste afficherait et compterait deux fois la même personne.
  List<ContactModel> _deduplicate(List<ContactModel> contacts) {
    final seen = <String>{};
    final unique = <ContactModel>[];
    for (final contact in contacts) {
      if (seen.add(contact.selectionKey)) {
        unique.add(contact);
      }
    }
    return unique;
  }
}
