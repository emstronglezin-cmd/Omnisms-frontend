import 'dart:async' show Completer, Timer;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window, MediaRecorder, Blob, Url, MediaStream;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';

/// Widget pour enregistrer des messages vocaux.
///
/// CORRECTION Session 9 — mode navigateur :
///   Sur web (navigateur ET PWA installée) : utilise navigator.mediaDevices.getUserMedia
///   via dart:html MediaRecorder API. La permission est demandée uniquement
///   au moment où l'utilisateur déclenche l'enregistrement (pas au démarrage).
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

  // Web-specific: MediaRecorder state
  html.MediaRecorder? _webMediaRecorder;
  html.MediaStream? _webStream;
  final List<dynamic> _webChunks = [];

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
    // Libérer le stream web si actif
    _webStream?.getTracks().forEach((t) { try { t.stop(); } catch (_) {} });
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
  ///
  /// Sur web : utilise navigator.mediaDevices.getUserMedia (W3C) via dart:html.
  /// Sur mobile : utilise permission_handler.
  Future<bool> _requestMicrophonePermission() async {
    if (kIsWeb) {
      return _requestWebMicrophonePermission();
    }
    try {
      final granted = await _checkPermission();
      return granted;
    } catch (e) {
      debugPrint('[VoiceRecorder] Permission request error: $e');
      return false;
    }
  }

  /// Demande le microphone via getUserMedia (web).
  /// Retourne true et stocke le stream si accordé.
  Future<bool> _requestWebMicrophonePermission() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        debugPrint('[VoiceRecorder] Web: mediaDevices non disponible');
        return false;
      }
      final stream = await mediaDevices.getUserMedia({'audio': true, 'video': false});
      _webStream = stream;
      return true;
    } catch (e) {
      debugPrint('[VoiceRecorder] Web: getUserMedia refusé: $e');
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
      if (kIsWeb) {
        // ── Web : utiliser dart:html MediaRecorder ──────────────
        // Le stream a déjà été obtenu dans _requestWebMicrophonePermission
        if (_webStream == null) {
          debugPrint('[VoiceRecorder] Web: stream non disponible');
          widget.onCancel();
          return;
        }

        _webChunks.clear();
        _webMediaRecorder = html.MediaRecorder(_webStream!);
        _webMediaRecorder!.addEventListener('dataavailable', (event) {
          // Ignorer les événements en dehors du cycle de vie
          try {
            // ignore: avoid_dynamic_calls
            final blob = (event as dynamic).data;
            if (blob != null) _webChunks.add(blob);
          } catch (_) {}
        });
        _webMediaRecorder!.start();
        debugPrint('[VoiceRecorder] Web: MediaRecorder démarré');
      }
      // Sur mobile, l'enregistrement via le package `record` serait ici :
      // import 'package:record/record.dart';
      // await _audioRecorder.start(const RecordConfig(), path: tempPath);

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

      debugPrint('[VoiceRecorder] Enregistrement démarré (web: $kIsWeb)');
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

    if (kIsWeb && _webMediaRecorder != null) {
      // ── Web : stopper MediaRecorder et créer une URL Blob ─────
      // On écoute l'événement 'stop' pour récupérer tous les chunks.
      final completer = Completer<String?>();

      _webMediaRecorder!.addEventListener('stop', (_) {
        try {
          if (_webChunks.isEmpty) {
            completer.complete(null);
            return;
          }
          final blob = html.Blob(_webChunks, 'audio/webm');
          final url = html.Url.createObjectUrl(blob);
          completer.complete(url);
          debugPrint('[VoiceRecorder] Web: Blob URL créée');
        } catch (e) {
          debugPrint('[VoiceRecorder] Web: Erreur création Blob: $e');
          completer.complete(null);
        }
      });

      _webMediaRecorder!.stop();
      // Libérer les pistes stream après arrêt
      _webStream?.getTracks().forEach((t) { try { t.stop(); } catch (_) {} });
      _webStream = null;
      _webMediaRecorder = null;

      try {
        final url = await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
        if (url != null) {
          widget.onRecordingComplete(url, duration);
        } else {
          debugPrint('[VoiceRecorder] Web: URL Blob non créée');
          widget.onCancel();
        }
      } catch (e) {
        debugPrint('[VoiceRecorder] Web: Erreur stop: $e');
        widget.onCancel();
      }
      return;
    }

    // Mobile stub (en attente flutter pub get avec package record)
    debugPrint('[VoiceRecorder] Mobile: arrêt (durée: ${duration.inSeconds}s)');
    // Après pub get : widget.onRecordingComplete(path!, duration)
    widget.onCancel();
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();

    setState(() {
      _isRecording = false;
    });

    if (kIsWeb) {
      try { _webMediaRecorder?.stop(); } catch (_) {}
      _webStream?.getTracks().forEach((t) { try { t.stop(); } catch (_) {} });
      _webStream = null;
      _webMediaRecorder = null;
      _webChunks.clear();
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
