import 'package:flutter/material.dart';
import '../services/video_ads_service.dart';

/// Widget bannière publicitaire PropellerAds
/// Remplace l'ancienne bannière Start.io
class AdBannerWidget extends StatelessWidget {
  const AdBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const PropellerAdBanner(height: 90);
  }
}
