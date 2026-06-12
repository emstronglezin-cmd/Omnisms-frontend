import 'package:flutter/foundation.dart';

/// AdsService - Stub vide pour compatibilité
/// Start.io a été supprimé, PropellerAds est utilisé à la place
class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  bool _isInitialized = false;

  /// Initialize (no-op)
  Future<void> initialize() async {
    _isInitialized = true;
    debugPrint('✅ AdsService initialized (PropellerAds used instead)');
  }

  /// Create banner ad (no-op)
  Future<dynamic> createBannerAd() async {
    return null;
  }

  /// Load interstitial ad (no-op)
  Future<void> loadInterstitialAd() async {
    // No-op
  }

  /// Show interstitial ad (no-op)
  Future<void> showInterstitialAd() async {
    // No-op
  }

  /// Dispose banner ad (no-op)
  void disposeBannerAd() {
    // No-op
  }

  /// Check if ads are available
  bool get isAvailable => false;
}
