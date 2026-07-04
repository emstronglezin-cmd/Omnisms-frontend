import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OmniSMS')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {},
              child: const Text('Afficher Pub Interstitielle'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Regarder vidéo récompensée'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> giveRewardToUser() async {
  try {
    final response = await http.post(
      Uri.parse('https://omnisms-backend.onrender.com/api/reward'),
      body: jsonEncode({'userId': 'ID_USER'}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      debugPrint('Reward given successfully');
    } else {
      debugPrint('Failed to give reward');
    }
  } catch (e) {
    debugPrint('Reward error: $e');
  }
}
