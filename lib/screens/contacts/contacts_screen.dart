import 'package:flutter/material.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> mockContacts = [
    {
      'name': 'Alice Martin',
      'phone': '+33612345678',
      'isRegistered': true,
      'avatar': 'AM'
    },
    {
      'name': 'Bob Dupont',
      'phone': '+33687654321',
      'isRegistered': false,
      'avatar': 'BD'
    },
    {
      'name': 'Charlie Bernard',
      'phone': '+33698765432',
      'isRegistered': true,
      'avatar': 'CB'
    },
    {
      'name': 'Diana Leclerc',
      'phone': '+33612987654',
      'isRegistered': true,
      'avatar': 'DL'
    },
  ];

  late List<Map<String, dynamic>> filteredContacts;

  @override
  void initState() {
    super.initState();
    filteredContacts = mockContacts;
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredContacts = mockContacts;
      } else {
        filteredContacts = mockContacts
            .where((contact) =>
                contact['name']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                contact['phone'].toString().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = filteredContacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF6366F1),
                    child: Text(
                      contact['avatar'],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(contact['name']),
                  subtitle: Text(contact['phone']),
                  trailing: contact['isRegistered']
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Sur OmniSMS',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    // Ouvrir conversation
                    Navigator.pushNamed(context, '/conversation');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
