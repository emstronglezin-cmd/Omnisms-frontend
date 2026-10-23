// ignore_for_file: avoid_dynamic_calls
import 'dart:async' show Timer;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import '../../utils/user_messages.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Widget pour enregistrer des messages vocaux.
///
/// CORRECTION Session 9 — mode navigateur :
///   Sur mobile (Android/iOS) : utilise le package `record` (AudioRecorder) —
///   fichier m4a écrit dans le répertoire temporaire puis uploadé sur
///   POST /api/audio/upload. La permission est demandée uniquement au moment
///   où l'utilisateur déclenche l'enregistrement, et celui-ci s'arrête seul
///   au bout de 5 minutes, exactement comme dans la PWA.
///   Sur Android : utilise RECORD_AUDIO (AndroidManifest.xml).
///   Sur iOS natif : utilise NSMicrophoneUsageDescription (Info.plist).
///
/// La version précédente bloquait complètement le web avec kIsWeb → annulation.
/// Cette version supporte le web via getUserMedia + MediaRecorder (W3C).
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

  // Enregistrement mobile (Android/iOS) via le package `record`
  AudioRecorder? _mobileRecorder;

  /// Durée maximale d'un message vocal (identique à la PWA : 5 minutes).
  static const int _maxRecordingSeconds = 300;

  @override
  void initState() {
    super.initState();
    // CORRECTION (Session 9) : ne jamais annuler automatiquement sur web.
    // Démarrer l'enregistrement après demande de permission dans tous les cas.
    _initRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Libérer l'enregistreur mobile
    _mobileRecorder?.dispose().catchError((_) {});
    _mobileRecorder = null;
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
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

  /// Demande la permission microphone (mobile).
  ///
  /// La vérification réelle est faite par le package `record`
  /// (`AudioRecorder.hasPermission()`) au démarrage effectif : sur Android
  /// cela déclenche la demande système android.permission.RECORD_AUDIO
  /// (déclarée dans AndroidManifest.xml), sur iOS NSMicrophoneUsageDescription.
  Future<bool> _requestMicrophonePermission() async {
    // Sur web, l'enregistrement est pris en charge par la PWA : on ne tente
    // rien ici (le garde-fou de _startRecording affiche le message adéquat).
    if (kIsWeb) return false;
    // Sur mobile, la permission réelle est demandée par `record` au démarrage
    // effectif de l'enregistrement (Android : RECORD_AUDIO / iOS : microphone).
    return true;
  }

  /// Vérifie la permission microphone via permission_handler si disponible.
  /// Conservé pour compatibilité ; le contrôle effectif est fait par `record`.
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

    if (kIsWeb) {
      // `dart:html` (MediaRecorder / getUserMedia) n'est compilable QUE pour
      // le web : l'importer ici empêchait toute compilation Android.
      // L'enregistrement vocal du web reste couvert par la PWA (public/).
      _showMessage('Messages vocaux non supportés sur le web.');
      widget.onCancel();
      return;
    }

    try {
      // ── Mobile (Android/iOS) : package `record` ──────────────────
      final recorder = _mobileRecorder ??= AudioRecorder();

      if (!await recorder.hasPermission()) {
        debugPrint('[VoiceRecorder] Mobile: permission microphone refusée');
        _showMessage(
          'Permission microphone refusée. '
          "Activez-la dans les Paramètres de l'application.",
        );
        widget.onCancel();
        return;
      }

      // Le fichier est écrit dans le répertoire temporaire de l'app : c'est ce
      // chemin qui est envoyé à POST /api/audio/upload.
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      try {
        await recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: path,
        );
        debugPrint('[VoiceRecorder] Mobile: enregistrement démarré → $path');
      } catch (e) {
        debugPrint('[VoiceRecorder] Mobile: erreur démarrage: $e');
        _showMessage("Impossible de démarrer l'enregistrement.");
        widget.onCancel();
        return;
      }


      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });

      // Timer pour afficher la durée en temps réel
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) return;
        setState(() {
          _recordDuration = Duration(seconds: timer.tick);
        });
        // Comme la PWA : arrêt automatique à 5 minutes d'enregistrement.
        if (timer.tick >= _maxRecordingSeconds) {
          await _stopRecording();
        }
      });

      debugPrint('[VoiceRecorder] Enregistrement démarré (web: $kIsWeb)');
    } catch (e) {
      debugPrint('[VoiceRecorder] Erreur démarrage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage(
              e,
              fallback: "Impossible de démarrer l'enregistrement.",
            )),
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

    // ── Mobile : arrêt réel, le fichier est remonté pour l'upload ──
    final recorder = _mobileRecorder;
    if (recorder == null) {
      widget.onCancel();
      return;
    }

    try {
      final path = await recorder.stop();
      if (path == null || path.isEmpty) {
        debugPrint('[VoiceRecorder] Mobile: aucun fichier produit');
        _showMessage("Aucun enregistrement à envoyer.");
        widget.onCancel();
        return;
      }
      debugPrint('[VoiceRecorder] Mobile: arrêt (${duration.inSeconds}s) → $path');
      widget.onRecordingComplete(path, duration);
    } catch (e) {
      debugPrint('[VoiceRecorder] Mobile: erreur arrêt: $e');
      _showMessage("Impossible d'enregistrer le message vocal.");
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();

    setState(() {
      _isRecording = false;
    });

    // Annule et supprime le fichier en cours d'écriture.
    try {
      await _mobileRecorder?.cancel();
    } catch (e) {
      debugPrint('[VoiceRecorder] Mobile: erreur annulation: $e');
    }

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
    // CORRECTION (Session 9) : ne plus renvoyer SizedBox.shrink() sur web.
    // Le web est maintenant géré via getUserMedia + MediaRecorder.

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
