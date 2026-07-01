import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

/// Widget pour lire des messages vocaux
/// Sur web: utilise just_audio (compatible web)
/// Sur mobile: utilise just_audio avec progress bar
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final Duration duration;
  final String? transcription;
  final bool isMe;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.duration,
    this.transcription,
    this.isMe = false,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final just_audio.AudioPlayer _audioPlayer;

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isLoading = false;
  StreamSubscription<just_audio.PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _audioPlayer = just_audio.AudioPlayer();

    try {
      setState(() => _isLoading = true);

      await _audioPlayer.setUrl(widget.audioUrl);

      _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }

        if (state.processingState == just_audio.ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
        }
      });

      _positionSubscription = _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      });

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  void _changePlaybackSpeed() {
    final speeds = [1.0, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextSpeed = speeds[(currentIndex + 1) % speeds.length];

    setState(() {
      _playbackSpeed = nextSpeed;
    });

    _audioPlayer.setSpeed(nextSpeed);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isMe ? Colors.white : const Color(0xFF0084FF);
    final backgroundColor = widget.isMe ? const Color(0xFF0084FF) : Colors.grey[200];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: _isLoading ? null : _togglePlayPause,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withOpacity(0.2),
                  ),
                  child: _isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: primaryColor,
                          size: 20,
                        ),
                ),
              ),

              const SizedBox(width: 8),

              // Progress bar (web-safe, no audio_waveforms)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: primaryColor,
                        inactiveTrackColor: primaryColor.withOpacity(0.3),
                        thumbColor: primaryColor,
                      ),
                      child: Slider(
                        value: _currentPosition.inMilliseconds
                            .clamp(0, widget.duration.inMilliseconds)
                            .toDouble(),
                        max: widget.duration.inMilliseconds > 0
                            ? widget.duration.inMilliseconds.toDouble()
                            : 1.0,
                        onChanged: (value) async {
                          final position = Duration(milliseconds: value.toInt());
                          await _audioPlayer.seek(position);
                        },
                      ),
                    ),
                    Text(
                      '${_formatDuration(_currentPosition)} / ${_formatDuration(widget.duration)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isMe ? Colors.white70 : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Playback speed button
              GestureDetector(
                onTap: _changePlaybackSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Transcription display
          if (widget.transcription != null && widget.transcription!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.text_fields,
                    size: 14,
                    color: widget.isMe ? Colors.white70 : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.transcription!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: widget.isMe ? Colors.white : Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
