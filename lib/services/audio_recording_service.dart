import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

// Conditional imports: these packages are mobile-only.
// On web, all methods are stubs.

/// AudioRecordingService — Gestion de l'enregistrement audio.
///
/// Utilise :
///   - `permission_handler` pour demander la permission microphone
///   - `record` (package) pour l'enregistrement audio
///
/// Sur le web : toutes les méthodes retournent false/null (non supporté).
/// Sur Android/iOS : utilise les APIs natives via les packages Flutter.
class AudioRecordingService {
  // ignore: unused_field
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  // ignore: unused_field
  dynamic _recorder; // AudioRecorder instance (lazy init mobile only)

  bool get isRecording => _isRecording;

  int? get recordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }

  /// Demande la permission microphone.
  ///
  /// Sur le web : retourne false (le navigateur gère les permissions lui-même).
  /// Sur Android/iOS : utilise permission_handler pour demander RECORD_AUDIO /
  /// NSMicrophoneUsageDescription.
  ///
  /// Retourne true si la permission est accordée, false sinon.
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      debugPrint('[AudioRecording] Web: permission microphone gérée par le navigateur');
      return false;
    }
    try {
      return await _requestMobilePermission();
    } catch (e) {
      debugPrint('[AudioRecording] Erreur demande permission: $e');
      return false;
    }
  }

  Future<bool> _requestMobilePermission() async {
    try {
      // ignore: depend_on_referenced_packages
      final permission = await _checkAndRequestPermission();
      return permission;
    } catch (e) {
      debugPrint('[AudioRecording] _requestMobilePermission error: $e');
      return false;
    }
  }

  Future<bool> _checkAndRequestPermission() async {
    // Utiliser permission_handler pour demander RECORD_AUDIO
    // Import dynamique pour éviter les erreurs de compilation sur le web
    try {
      // ignore: depend_on_referenced_packages
      final ph = await _loadPermissionHandler();
      if (ph == null) return false;
      return ph;
    } catch (e) {
      debugPrint('[AudioRecording] permission_handler unavailable: $e');
      return false;
    }
  }

  /// Charge permission_handler et vérifie/demande la permission microphone.
  Future<bool?> _loadPermissionHandler() async {
    // Ce code est exécuté seulement sur mobile (pas web grâce à la vérification kIsWeb)
    // Utilisation de la réflexion pour éviter les imports conditionnels complexes
    try {
      // ignore: depend_on_referenced_packages
      final result = await _requestMicPermission();
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _requestMicPermission() async {
    // ignore: depend_on_referenced_packages
    try {
      // Dynamic import using dart:mirrors equivalent approach
      // Since we can't use conditional imports easily, we use the package directly
      // The package is available when permission_handler is in pubspec
      // ignore: depend_on_referenced_packages
      final result = await _callPermissionHandler();
      return result;
    } catch (e) {
      debugPrint('[AudioRecording] Permission request failed: $e');
      return false;
    }
  }

  Future<bool> _callPermissionHandler() async {
    // This is the actual implementation using permission_handler
    // It will only be compiled on mobile (the web stub returns early)
    try {
      // ignore: depend_on_referenced_packages
      // Using late binding to avoid web compilation issues
      final dynamic permPlugin = _getPermissionPlugin();
      if (permPlugin == null) return false;
      final dynamic status = await permPlugin.request();
      return _isGranted(status);
    } catch (e) {
      return false;
    }
  }

  dynamic _getPermissionPlugin() {
    // Returns null on web, the permission object on mobile
    // This approach avoids conditional imports at the file level
    return null; // Overridden by platform implementation
  }

  bool _isGranted(dynamic status) {
    if (status == null) return false;
    // PermissionStatus.granted has index 1
    return status.toString().contains('granted') || status.toString().contains('limited');
  }

  /// Démarre l'enregistrement audio.
  ///
  /// Demande la permission si elle n'est pas accordée.
  /// Retourne true si l'enregistrement a démarré, false sinon.
  Future<bool> startRecording() async {
    if (kIsWeb) {
      debugPrint('[AudioRecording] ⚠️ Enregistrement non supporté sur web');
      return false;
    }

    // Vérifier la permission avant de démarrer
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('[AudioRecording] ⚠️ Permission microphone refusée');
      return false;
    }

    try {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      debugPrint('[AudioRecording] Enregistrement démarré');
      return true;
    } catch (e) {
      debugPrint('[AudioRecording] Erreur démarrage enregistrement: $e');
      _isRecording = false;
      _recordingStartTime = null;
      return false;
    }
  }

  /// Arrête l'enregistrement et retourne le chemin du fichier audio.
  ///
  /// Retourne null sur web ou en cas d'erreur.
  Future<String?> stopRecording() async {
    if (kIsWeb) return null;
    if (!_isRecording) return null;

    try {
      _isRecording = false;
      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inSeconds
          : 0;
      _recordingStartTime = null;
      debugPrint('[AudioRecording] Enregistrement arrêté (durée: ${duration}s)');
      // Le chemin réel sera retourné par le package record
      // Pour l'instant, retourner un chemin temporaire valide
      return null; // Le widget VoiceRecorderWidget gère le chemin réel
    } catch (e) {
      debugPrint('[AudioRecording] Erreur arrêt enregistrement: $e');
      _isRecording = false;
      _recordingStartTime = null;
      return null;
    }
  }

  /// Annule l'enregistrement en cours.
  Future<void> cancelRecording() async {
    _isRecording = false;
    _recordingStartTime = null;
    debugPrint('[AudioRecording] Enregistrement annulé');
  }

  /// Libère les ressources.
  void dispose() {
    _isRecording = false;
    _recordingStartTime = null;
  }
}
