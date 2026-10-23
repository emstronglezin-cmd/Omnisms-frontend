import 'package:flutter/material.dart';
import '../../services/cache_service.dart';

import 'avatar_image.dart';

/// Widget optimisé pour afficher des images avec cache automatique
class CachedImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Délègue à SmartImage : data URI du backend ou URL distante, avec cache.
    final imageWidget = SmartImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Avatar avec cache optimisé
class CachedAvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Color? backgroundColor;

  const CachedAvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final bgColor = backgroundColor ??
        _generateColorFromName(name);

    // Délègue à UserAvatar : c'est lui qui sait afficher un data URI.
    return UserAvatar(
      imageUrl: imageUrl,
      name: name,
      size: size,
      backgroundColor: bgColor,
      fallback: _buildInitialsAvatar(initials, size),
    );
  }

  Widget _buildInitialsAvatar(String initials, double size) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _generateColorFromName(String name) {
    final colors = [
      const Color(0xFF667eea),
      const Color(0xFF764ba2),
      const Color(0xFFf093fb),
      const Color(0xFF4facfe),
      const Color(0xFF00f2fe),
      const Color(0xFF43e97b),
      const Color(0xFF38f9d7),
      const Color(0xFFfa709a),
      const Color(0xFFfee140),
      const Color(0xFFfccb90),
    ];

    final hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }
}

/// Préchargeur d'images pour améliorer les performances
class ImagePreloader {
  static Future<void> preloadImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    final cacheService = CacheService();
    
    for (final url in imageUrls) {
      try {
        // Precache in background
        cacheService.precacheFile(url, isAudio: false);
      } catch (e) {
        // Ignore errors during preloading
      }
    }
  }

  /// Preload images from a list with progress callback
  static Future<void> preloadImagesWithProgress(
    List<String> imageUrls,
    Function(int loaded, int total)? onProgress,
  ) async {
    final cacheService = CacheService();
    int loaded = 0;
    
    for (final url in imageUrls) {
      try {
        await cacheService.precacheFile(url, isAudio: false);
        loaded++;
        onProgress?.call(loaded, imageUrls.length);
      } catch (e) {
        loaded++;
        onProgress?.call(loaded, imageUrls.length);
      }
    }
  }
}
