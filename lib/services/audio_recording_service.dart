import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

// dart:io is mobile only — conditionally imported
// On web, all methods return stubs
class AudioRecordingService {
  bool _isRecording = false;
  DateTime? _recordingStartTime;

  bool get isRecording => _isRecording;
  int? get recordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }

  // Request microphone permission
  Future<bool> requestPermission() async {
    if (kIsWeb) return false; // Web uses browser permissions natively
    try {
      // Dynamic import to avoid web compilation error
      return await _requestMobilePermission();
    } catch (e) {
      debugPrint('Permission error: $e');
      return false;
    }
  }

  Future<bool> _requestMobilePermission() async {
    // This code only runs on mobile
    try {
      // ignore: depend_on_referenced_packages
      final permission = await _getPermission();
      return permission;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _getPermission() async {
    // Stub - mobile implementation would use permission_handler
    return false;
  }

  // Start recording
  Future<bool> startRecording() async {
    if (kIsWeb) {
      debugPrint('⚠️ Audio recording not supported on web');
      return false;
    }
    debugPrint('⚠️ Audio recording: mobile-only feature');
    return false;
  }

  // Stop recording — returns null on web
  Future<dynamic> stopRecording() async {
    if (kIsWeb) return null;
    _isRecording = false;
    _recordingStartTime = null;
    return null;
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    _isRecording = false;
    _recordingStartTime = null;
  }

  // Dispose
  void dispose() {
    // No-op on web
  }
}
