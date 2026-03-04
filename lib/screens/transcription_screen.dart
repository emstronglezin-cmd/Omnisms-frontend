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
  bool _isRecorderInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();
      if (mounted) {
        setState(() {
          _isRecorderInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Erreur initialisation recorder: $e');
      if (mounted) {
        setState(() {
          _error = 'Impossible d\'initialiser l\'enregistreur audio';
        });
      }
    }
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) {
      setState(() {
        _error = 'Enregistreur non initialisé';
      });
      return;
    }

    try {
      await _recorder.startRecorder(toFile: 'audio.aac');
      setState(() {
        _isRecording = true;
        _error = null;
      });
    } catch (e) {
      debugPrint('Erreur démarrage enregistrement: $e');
      setState(() {
        _error = 'Erreur lors du démarrage de l\'enregistrement';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final filePath = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });
      if (filePath != null) {
        _transcribeAudio(filePath);
      }
    } catch (e) {
      debugPrint('Erreur arrêt enregistrement: $e');
      setState(() {
        _isRecording = false;
        _error = 'Erreur lors de l\'arrêt de l\'enregistrement';
      });
    }
  }

  Future<void> _transcribeAudio(String filePath) async {
    try {
      final transcription = await TranscriptionService().transcribeAudio(
        filePath,
      );
      if (mounted) {
        setState(() {
          _transcription = transcription;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('Erreur transcription: $e');
      if (mounted) {
        setState(() {
          _error = 'Erreur lors de la transcription';
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      _recorder.closeRecorder();
    } catch (e) {
      debugPrint('Erreur fermeture recorder: $e');
    }
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            if (!_isRecorderInitialized)
              const CircularProgressIndicator()
            else if (_isRecording)
              const Text('Enregistrement en cours...')
            else
              ElevatedButton(
                onPressed: _startRecording,
                child: const Text("Commencer l'enregistrement"),
              ),
            if (_isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: ElevatedButton(
                  onPressed: _stopRecording,
                    child: const Text("Arrêter l'enregistrement"),
                ),
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
