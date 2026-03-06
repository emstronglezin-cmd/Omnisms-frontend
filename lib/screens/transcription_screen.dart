import 'package:flutter/material.dart';
import '../services/transcription_service.dart';

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({Key? key}) : super(key: key);

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  // Recording functionality temporarily disabled due to dependency issues.
  String? _transcription;

  Future<void> _transcribeAudio(String filePath) async {
    final transcription = await TranscriptionService().transcribeAudio(
      filePath,
    );
    setState(() {
      _transcription = transcription;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transcription Audio')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('La fonctionnalité d’enregistrement est désactivée.'),
            if (_transcription != null)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Text('Transcription : $_transcription'),
              ),
          ],
        ),
      ),
    );
  }

}
