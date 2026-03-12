import 'package:flutter/material.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final List<String> mockMembers = [
    'Alice Martin',
    'Bob Dupont',
    'Charlie Bernard',
    'Diana Leclerc',
    'Eva Rousseau',
  ];
  final Set<String> selectedMembers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un groupe'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Nom du groupe
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nom du groupe',
              hintText: 'Ex: Dev Team',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Sélectionner membres
          const Text(
            'Sélectionner les membres',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...mockMembers.map((member) {
            final isSelected = selectedMembers.contains(member);
            return CheckboxListTile(
              title: Text(member),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    selectedMembers.add(member);
                  } else {
                    selectedMembers.remove(member);
                  }
                });
              },
            );
          }).toList(),
          const SizedBox(height: 24),
          // Bouton créer
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: selectedMembers.isNotEmpty
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Groupe créé!')),
                    );
                    Navigator.pop(context);
                  }
                : null,
            child: const Text(
              'Créer le groupe',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
