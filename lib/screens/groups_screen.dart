import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<String> groups = [];

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    final fetchedGroups = await ApiService().getGroups();
    setState(() {
      groups = fetchedGroups;
    });
  }

  void _createGroup() async {
    final newGroup = await ApiService().createGroup('Nouveau Groupe');
    if (newGroup != null) {
      setState(() {
        groups.add(newGroup);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groupes')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(groups[index]),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GroupMessagesScreen(groupId: groups[index]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: _createGroup,
            child: const Text('Créer un groupe'),
          ),
        ],
      ),
    );
  }
}

class GroupMessagesScreen extends StatelessWidget {
  final String groupId;

  const GroupMessagesScreen({Key? key, required this.groupId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Messages du groupe $groupId')),
      body: Center(
        child: Text('Affichage des messages pour le groupe $groupId'),
      ),
    );
  }
}
