import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Service de gestion du cache pour les images et médias
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  /// Cache manager personnalisé pour les images
  static final CacheManager imageCache = CacheManager(
    Config(
      'omnisms_images',
      stalePeriod: const Duration(days: 7), // Cache images for 7 days
      maxNrOfCacheObjects: 200, // Max 200 cached images
      repo: JsonCacheInfoRepository(databaseName: 'omnisms_images'),
      fileService: HttpFileService(),
    ),
  );

  /// Cache manager pour les fichiers audio
  static final CacheManager audioCache = CacheManager(
    Config(
      'omnisms_audio',
      stalePeriod: const Duration(days: 30), // Cache audio for 30 days
      maxNrOfCacheObjects: 100, // Max 100 cached audio files
      repo: JsonCacheInfoRepository(databaseName: 'omnisms_audio'),
      fileService: HttpFileService(),
    ),
  );

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await imageCache.emptyCache();
    await audioCache.emptyCache();
  }

  /// Clear only image cache
  Future<void> clearImageCache() async {
    await imageCache.emptyCache();
  }

  /// Clear only audio cache
  Future<void> clearAudioCache() async {
    await audioCache.emptyCache();
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    try {
      // This is an approximation
      final imageFiles = await imageCache.getFileFromMemory('');
      final audioFiles = await audioCache.getFileFromMemory('');
      
      // Would need to iterate through all cached files to get accurate size
      // For now, return 0 as placeholder
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Remove a specific file from cache
  Future<void> removeFile(String url, {bool isAudio = false}) async {
    final cache = isAudio ? audioCache : imageCache;
    await cache.removeFile(url);
  }

  /// Pre-cache a file
  Future<void> precacheFile(String url, {bool isAudio = false}) async {
    final cache = isAudio ? audioCache : imageCache;
    try {
      await cache.downloadFile(url);
    } catch (e) {
      // Ignore errors for precaching
    }
  }
}
