import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            const url =
                'https://precious-gerbil-810.notion.site/OmniSMS-Version-Pro-2e652fe9103980e7aabbd2e01c4c2941';
            if (await canLaunchUrlString(url)) {
              await launchUrlString(url);
            } else {
              throw 'Could not launch $url';
            }
          },
          child: const Text('Passer en version Pro'),
        ),
      ),
    );
  }
}
