import 'package:flutter/material.dart';

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
  final response = await http.post(
    Uri.parse('http://51.15.89.72/api/reward'),
    body: jsonEncode({'userId': 'ID_USER'}),
    headers: {'Content-Type': 'application/json'},
  );
  if (response.statusCode == 200) {
    debugPrint('Reward given successfully');
  } else {
    debugPrint('Failed to give reward');
  }
}
