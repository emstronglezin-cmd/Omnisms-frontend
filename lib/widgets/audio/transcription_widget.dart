import 'package:flutter/material.dart';

/// Widget pour afficher la transcription d'un message vocal
class TranscriptionWidget extends StatelessWidget {
  final String transcription;
  final bool isMe;
  final bool isLoading;
  final VoidCallback? onRetry;

  const TranscriptionWidget({
    super.key,
    required this.transcription,
    this.isMe = false,
    this.isLoading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isMe 
        ? Colors.white.withOpacity(0.2)
        : Colors.grey[300];
    
    final textColor = isMe ? Colors.white : Colors.grey[800];
    final iconColor = isMe ? Colors.white70 : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe 
              ? Colors.white.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.text_fields,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Transcription',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
              const Spacer(),
              if (isLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor!),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Transcription text or loading state
          if (isLoading)
            _buildLoadingState(iconColor)
          else if (transcription.isEmpty && onRetry != null)
            _buildErrorState(textColor, iconColor)
          else
            _buildTranscriptionText(textColor),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color? color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerLine(width: double.infinity, color: color),
        const SizedBox(height: 6),
        _buildShimmerLine(width: 180, color: color),
        const SizedBox(height: 6),
        _buildShimmerLine(width: 220, color: color),
      ],
    );
  }

  Widget _buildShimmerLine({required double width, Color? color}) {
    return Container(
      height: 12,
      width: width,
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildErrorState(Color? textColor, Color? iconColor) {
    return Row(
      children: [
        Icon(
          Icons.error_outline,
          size: 16,
          color: Colors.red.withOpacity(0.8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Échec de la transcription',
            style: TextStyle(
              fontSize: 12,
              color: textColor?.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        if (onRetry != null)
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    size: 14,
                    color: iconColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Réessayer',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTranscriptionText(Color? textColor) {
    return SelectableText(
      transcription,
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: textColor,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// Widget minimaliste pour afficher la transcription inline dans une bulle
class InlineTranscriptionWidget extends StatelessWidget {
  final String transcription;
  final bool isMe;

  const InlineTranscriptionWidget({
    super.key,
    required this.transcription,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isMe ? Colors.white70 : Colors.grey[700];
    
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.text_snippet_outlined,
            size: 12,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              transcription,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: textColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
