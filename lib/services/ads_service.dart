import 'package:flutter/foundation.dart';
import 'package:startapp_sdk/startapp.dart';

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  var startAppSdk = StartAppSdk();
  StartAppBannerAd? _bannerAd;
  StartAppInterstitialAd? _interstitialAd;
  bool _isInitialized = false;

  /// Initialize Start.io SDK
  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) {
      // Start.io doesn't support web
      return;
    }

    try {
      // Initialize SDK
      await startAppSdk.loadAd(StartAppAdType.REWARDED);
      
      _isInitialized = true;
      debugPrint('✅ Start.io Ads initialized successfully');
      
      // Load interstitial ad in advance
      await loadInterstitialAd();
    } catch (e) {
      debugPrint('❌ Error initializing Start.io Ads: $e');
      _isInitialized = false;
    }
  }

  /// Create and show banner ad
  Future<StartAppBannerAd?> createBannerAd() async {
    if (!_isInitialized || kIsWeb) return null;

    try {
      _bannerAd = StartAppBannerAd(StartAppBannerType.BANNER);
      debugPrint('✅ Banner ad created');
      return _bannerAd;
    } catch (e) {
      debugPrint('❌ Error loading banner ad: $e');
      return null;
    }
  }

  /// Load interstitial ad
  Future<void> loadInterstitialAd() async {
    if (!_isInitialized || kIsWeb) return;

    try {
      _interstitialAd = StartAppInterstitialAd();
      await startAppSdk.loadAd(StartAppAdType.INTERSTITIAL);
      debugPrint('✅ Interstitial ad loaded');
    } catch (e) {
      debugPrint('❌ Error loading interstitial ad: $e');
    }
  }

  /// Show interstitial ad
  Future<void> showInterstitialAd() async {
    if (!_isInitialized || _interstitialAd == null || kIsWeb) return;

    try {
      await _interstitialAd!.show();
      debugPrint('✅ Interstitial ad shown');
      
      // Load next ad
      await loadInterstitialAd();
    } catch (e) {
      debugPrint('❌ Error showing interstitial ad: $e');
    }
  }

  /// Dispose banner ad
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  /// Check if ads are available
  bool get isAvailable => _isInitialized && !kIsWeb;
}
