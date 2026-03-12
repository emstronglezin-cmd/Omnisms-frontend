import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecordingService {
  final Record _recorder = Record();
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;

  bool get isRecording => _isRecording;
  int? get recordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }

  // Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Start recording
  Future<bool> startRecording() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        print('Microphone permission denied');
        return false;
      }

      // Create temp directory for recordings
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${dir.path}/recording_$timestamp.m4a';

      await _recorder.start(
        path: _recordingPath!,
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        samplingRate: 44100,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      _isRecording = false;
      return false;
    }
  }

  // Stop recording
  Future<File?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _recorder.stop();
      _isRecording = false;
      _recordingStartTime = null;

      if (path != null && File(path).existsSync()) {
        return File(path);
      }
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
        _recordingStartTime = null;

        // Delete the recording file
        if (_recordingPath != null && File(_recordingPath!).existsSync()) {
          await File(_recordingPath!).delete();
        }
      }
    } catch (e) {
      print('Error canceling recording: $e');
    }
  }

  // Dispose
  void dispose() {
    _recorder.dispose();
  }
}
