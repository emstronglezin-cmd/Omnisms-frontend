import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/groups_provider.dart';
import '../../widgets/common/avatar_image.dart';
import 'create_group_screen.dart';
import 'group_conversation_screen.dart';
import '../../theme/omni_motion.dart';
import '../../widgets/common/etats_v3.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupsProvider>().loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groupes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<GroupsProvider>().loadGroups();
            },
          ),
        ],
      ),
      body: Consumer<GroupsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const OmniEtatChargement();
          }

          if (provider.error != null) {
            return OmniEtatErreur(
              message: provider.error!,
              onReessayer: provider.loadGroups,
            );
          }

          if (provider.groups.isEmpty) {
            return OmniEtatVide(
              icone: Icons.groups_rounded,
              titre: 'Aucun groupe',
              message:
                  'Créez un groupe pour échanger à plusieurs avec vos contacts.',
              libelleAction: 'Créer un groupe',
              onAction: () {
                Navigator.push(
                  context,
                  OmniRoute<void>(
                    type: OmniTypeTransition.fondu,
                    builder: (_) => const CreateGroupScreen(),
                  ),
                ).then((_) => provider.loadGroups());
              },
            );
          }

          return ListView.builder(
            itemCount: provider.groups.length,
            itemBuilder: (context, index) {
              final group = provider.groups[index];
              // V3 — apparition en cascade, comme sur les autres listes.
              return OmniApparitionEspacee(
                index: index,
                child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  // Photo du groupe quand elle existe (stockée côté serveur
                  // sous `avatar`), icône de groupe sinon.
                  leading: UserAvatar(
                    imageUrl: group.photoUrl,
                    name: group.name,
                    size: 40,
                    fallback: Icon(
                      Icons.group,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(group.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (group.description != null)
                        Text(
                          group.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.memberIds.length} membres',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      OmniRoute<void>(
                        type: OmniTypeTransition.axePartage,
                        builder: (_) => GroupConversationScreen(
                          groupId: group.id,
                          groupName: group.name,
                        ),
                      ),
                    );
                  },
                  onLongPress: () {
                    _showGroupOptions(group.id, group.name);
                  },
                ),
              ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateGroupScreen(),
            ),
          ).then((_) {
            // Reload groups when returning
            context.read<GroupsProvider>().loadGroups();
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showGroupOptions(String groupId, String groupName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(context);
                _showEditGroupDialog(groupId, groupName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Ajouter des membres'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fonctionnalité bientôt disponible')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Quitter le groupe'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fonctionnalité bientôt disponible')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteGroup(groupId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupDialog(String groupId, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le groupe'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom du groupe',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await this.context.read<GroupsProvider>().updateGroup(
                    groupId,
                    name: controller.text.trim(),
                  );
              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Groupe modifié')),
                  );
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(String groupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: const Text('Voulez-vous vraiment supprimer ce groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await this.context.read<GroupsProvider>().deleteGroup(groupId);
              if (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Groupe supprimé')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
