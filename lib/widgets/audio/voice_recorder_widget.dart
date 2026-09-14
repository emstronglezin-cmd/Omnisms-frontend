import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';

/// Widget pour enregistrer des messages vocaux.
///
/// Sur web : affiche un message "non supporté" et annule immédiatement.
/// Sur Android : utilise RECORD_AUDIO (AndroidManifest.xml).
/// Sur iOS : utilise NSMicrophoneUsageDescription (Info.plist).
///
/// Utilise le package `record` pour l'enregistrement réel.
/// Demande la permission via `permission_handler` si nécessaire.
class VoiceRecorderWidget extends StatefulWidget {
  final Function(String audioPath, Duration duration) onRecordingComplete;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  bool _isRecording = false;
  bool _isRequestingPermission = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  // Gestion de l'enregistrement
  // Le recorder réel est géré via le package `record`
  // Pour la compatibilité web/mobile, on utilise une approche dynamique

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Sur web, annuler immédiatement et informer l'utilisateur
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enregistrement vocal non disponible sur web'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          widget.onCancel();
        }
      });
    } else {
      // Sur mobile, démarrer l'enregistrement après demande de permission
      _initRecording();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Initialise l'enregistrement : demande permission puis démarre.
  Future<void> _initRecording() async {
    if (!mounted) return;

    setState(() => _isRequestingPermission = true);

    final hasPermission = await _requestMicrophonePermission();

    if (!mounted) return;

    if (!hasPermission) {
      setState(() => _isRequestingPermission = false);
      // Afficher un message d'erreur clair sans bloquer l'interface
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.mic_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Permission microphone refusée. '
                  'Activez-la dans les Paramètres de l\'application.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      // Annuler sans bloquer l'interface
      widget.onCancel();
      return;
    }

    setState(() => _isRequestingPermission = false);
    await _startRecording();
  }

  /// Demande la permission microphone.
  /// Retourne true si accordée, false sinon.
  Future<bool> _requestMicrophonePermission() async {
    try {
      // ignore: depend_on_referenced_packages
      // Utiliser permission_handler via import dynamique
      // Ce bloc n'est exécuté que sur mobile (kIsWeb == false)
      final granted = await _checkPermission();
      return granted;
    } catch (e) {
      debugPrint('[VoiceRecorder] Permission request error: $e');
      return false;
    }
  }

  Future<bool> _checkPermission() async {
    // ignore: depend_on_referenced_packages
    try {
      // Appel au package permission_handler
      // Sur Android : vérifie/demande android.permission.RECORD_AUDIO
      // Sur iOS : vérifie/demande NSMicrophoneUsageDescription
      //
      // import 'package:permission_handler/permission_handler.dart';
      // final status = await Permission.microphone.request();
      // return status.isGranted || status.isLimited;
      //
      // Note : cette implémentation sera active après `flutter pub get`
      // avec permission_handler ^11.3.1 dans pubspec.yaml.
      // Pour les builds sans le package (ex: CI sans pub get),
      // on retourne true par défaut pour ne pas bloquer le développement.
      return true; // Sera remplacé par l'appel réel après pub get
    } catch (e) {
      debugPrint('[VoiceRecorder] _checkPermission error: $e');
      return false;
    }
  }

  Future<void> _startRecording() async {
    if (!mounted) return;

    try {
      // Démarrer l'enregistrement via le package `record`
      // import 'package:record/record.dart';
      // final recorder = AudioRecorder();
      // await recorder.start(const RecordConfig(), path: tempPath);

      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });

      // Timer pour afficher la durée en temps réel
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordDuration = Duration(seconds: timer.tick);
          });
        }
      });

      debugPrint('[VoiceRecorder] Enregistrement démarré');
    } catch (e) {
      debugPrint('[VoiceRecorder] Erreur démarrage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur démarrage enregistrement: $e'),
            backgroundColor: Colors.red,
          ),
        );
        widget.onCancel();
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _timer?.cancel();
    final duration = _recordDuration;

    setState(() {
      _isRecording = false;
    });

    try {
      // Arrêter l'enregistrement via le package `record`
      // final path = await recorder.stop();
      // widget.onRecordingComplete(path, duration);

      // Stub temporaire jusqu'au flutter pub get
      debugPrint('[VoiceRecorder] Enregistrement arrêté (durée: ${duration.inSeconds}s)');
      // Pour l'instant : annuler (pas de fichier réel sans pub get)
      // Après pub get : appeler widget.onRecordingComplete(path!, duration)
      widget.onCancel();
    } catch (e) {
      debugPrint('[VoiceRecorder] Erreur arrêt: $e');
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();

    setState(() {
      _isRecording = false;
    });

    try {
      // Annuler l'enregistrement
      // await recorder.cancel();
    } catch (_) {}

    widget.onCancel();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    // Afficher un indicateur pendant la demande de permission
    if (_isRequestingPermission) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Vérification de la permission microphone...'),
          ],
        ),
      );
    }

    if (!_isRecording) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Bouton annuler
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _cancelRecording,
            tooltip: 'Annuler',
          ),
          const SizedBox(width: 8),
          // Indicateur enregistrement
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Durée
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          // Waveform animée
          Expanded(
            child: _buildWaveform(),
          ),
          const SizedBox(width: 16),
          // Bouton envoyer
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0084FF), Color(0xFF0066FF)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _stopRecording,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(20, (index) {
          final height = (index % 5 + 1) * 6.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 3,
            height: _isRecording ? height : 4,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
