import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

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
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Check and request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission microphone requise'),
            ),
          );
          widget.onCancel();
        }
        return;
      }

      // Get temp directory
      final dir = await getTemporaryDirectory();
      _audioPath = '${dir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _audioPath!,
      );

      setState(() {
        _isRecording = true;
      });

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration = Duration(seconds: timer.tick);
        });
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        widget.onCancel();
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      await _audioRecorder.stop();
      _timer?.cancel();

      if (_audioPath != null && mounted) {
        widget.onRecordingComplete(_audioPath!, _recordDuration);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }

    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _cancelRecording() async {
    if (_isRecording) {
      await _audioRecorder.stop();
      _timer?.cancel();
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
      child: SafeArea(
        child: Row(
          children: [
            // Cancel button
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _cancelRecording,
            ),
            const SizedBox(width: 8),
            // Recording indicator
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
            // Duration
            Text(
              _formatDuration(_recordDuration),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            // Waveform placeholder (animated)
            Expanded(
              child: _buildWaveform(),
            ),
            const SizedBox(width: 16),
            // Send button
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
            height: height,
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
