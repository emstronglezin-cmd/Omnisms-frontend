import 'package:flutter/material.dart';
import 'package:startapp_sdk/startapp.dart';
import '../services/ads_service.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  final AdsService _adsService = AdsService();
  StartAppBannerAd? _bannerAd;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    if (!_adsService.isAvailable) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final ad = await _adsService.createBannerAd();
      if (mounted) {
        setState(() {
          _bannerAd = ad;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading banner ad: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _adsService.disposeBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_bannerAd == null || !_adsService.isAvailable) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 50,
      color: Colors.grey[100],
      child: StartAppBanner(_bannerAd!),
    );
  }
}
