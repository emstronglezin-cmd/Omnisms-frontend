import 'package:flutter/material.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final List<Map<String, dynamic>> mockGroups = [
    {
      'name': 'Dev Team',
      'members': 8,
      'lastMessage': 'Alice: À bientôt!',
      'avatar': 'DT'
    },
    {
      'name': 'Amis',
      'members': 5,
      'lastMessage': 'Bob: Haha 😂',
      'avatar': 'AM'
    },
    {
      'name': 'Projet Marketing',
      'members': 12,
      'lastMessage': 'Charlie: Parfait!',
      'avatar': 'PM'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groupes'),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: mockGroups.length,
        itemBuilder: (context, index) {
          final group = mockGroups[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1),
              child: Text(
                group['avatar'],
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(group['name']),
            subtitle: Text(group['lastMessage']),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${group['members']} membres',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () =>
                Navigator.pushNamed(context, '/groups/conversation',
                    arguments: group['name']),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6366F1),
        onPressed: () => Navigator.pushNamed(context, '/groups/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
