import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../services/transcription_service.dart';

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({Key? key}) : super(key: key);

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _transcription;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    await _recorder.openRecorder();
  }

  Future<void> _startRecording() async {
    await _recorder.startRecorder(toFile: 'audio.aac');
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    final filePath = await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    if (filePath != null) {
      _transcribeAudio(filePath);
    }
  }

  Future<void> _transcribeAudio(String filePath) async {
    final transcription = await TranscriptionService().transcribeAudio(
      filePath,
    );
    setState(() {
      _transcription = transcription;
    });
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
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
            if (_isRecording)
              const Text('Enregistrement en cours...')
            else
              ElevatedButton(
                onPressed: _startRecording,
                child: const Text('Commencer l’enregistrement'),
              ),
            if (_isRecording)
              ElevatedButton(
                onPressed: _stopRecording,
                child: const Text('Arrêter l’enregistrement'),
              ),
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
