import 'package:flutter/material.dart';
import 'conversation_screen.dart';

class ContactsScreen extends StatelessWidget {
  final void Function(String contactName)? onContactTap;
  const ContactsScreen({super.key, this.onContactTap});

  final List<String> contacts = const ['Alice', 'Bob', 'Charlie'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return ListTile(
            title: Text(contact),
            onTap: () {
              if (onContactTap != null) {
                onContactTap!(contact);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConversationScreen(contactName: contact),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
