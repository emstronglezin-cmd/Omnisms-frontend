import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../video_ads_service.dart';

export '../video_ads_service.dart' show PropellerAdBanner;

/// Widget PropellerAds bannière - Redirige vers le nouveau service
class PropellerAdsBanner extends StatelessWidget {
  final String zoneId;
  final double height;
  final bool enabled;

  const PropellerAdsBanner({
    super.key,
    required this.zoneId,
    this.height = 90,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled || !kIsWeb) return const SizedBox.shrink();
    return PropellerAdBanner(height: height);
  }
}

/// Configuration PropellerAds
class PropellerAdsConfig {
  static const String bannerZoneId = '11034847';
  static const String interstitialZoneId = '11034847';
  static const String pushNotificationZoneId = '11034847';

  static bool get adsEnabled => const bool.fromEnvironment(
        'ADS_ENABLED',
        defaultValue: true,
      );
}

/// Bannière prête à l'emploi
class PropellerBannerAd extends StatelessWidget {
  final double height;
  const PropellerBannerAd({super.key, this.height = 90});

  @override
  Widget build(BuildContext context) {
    return PropellerAdsBanner(
      zoneId: PropellerAdsConfig.bannerZoneId,
      height: height,
      enabled: PropellerAdsConfig.adsEnabled,
    );
  }
}
