import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

/// Widget pour afficher les bannières publicitaires PropellerAds
class PropellerAdsBanner extends StatefulWidget {
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
  State<PropellerAdsBanner> createState() => _PropellerAdsBannerState();
}

class _PropellerAdsBannerState extends State<PropellerAdsBanner> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    if (!widget.enabled) {
      return;
    }

    if (kIsWeb) {
      _initWebAd();
    } else {
      _initMobileAd();
    }
  }

  /// Initialize ad for Flutter Web
  void _initWebAd() {
    final String viewID = 'propeller-ad-${widget.zoneId}-${DateTime.now().millisecondsSinceEpoch}';
    
    // Ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewID,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..style.width = '100%'
          ..style.height = '${widget.height}px'
          ..style.border = 'none'
          ..srcdoc = _generateAdHtml();

        return iframe;
      },
    );

    setState(() {
      _isLoading = false;
    });
  }

  /// Initialize ad for Mobile (Android/iOS) using WebView
  void _initMobileAd() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(_generateAdHtml())
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      );
  }

  String _generateAdHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      width: 100%;
      height: ${widget.height}px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: transparent;
      overflow: hidden;
    }
    #ad-container {
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
    }
  </style>
</head>
<body>
  <div id="ad-container">
    <!-- PropellerAds banner code -->
    <script async src="https://cdn.propellerads.com/ads/ads.js?${widget.zoneId}"></script>
  </div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    return Container(
      height: widget.height,
      width: double.infinity,
      color: Colors.grey[100],
      child: _isLoading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : kIsWeb
              ? HtmlElementView(
                  viewType: 'propeller-ad-${widget.zoneId}-${DateTime.now().millisecondsSinceEpoch}',
                )
              : WebViewWidget(controller: _controller),
    );
  }
}

/// Configuration PropellerAds
class PropellerAdsConfig {
  // Zone IDs pour différents formats
  static const String bannerZoneId = 'YOUR_BANNER_ZONE_ID';
  static const String interstitialZoneId = 'YOUR_INTERSTITIAL_ZONE_ID';
  static const String pushNotificationZoneId = 'YOUR_PUSH_ZONE_ID';
  
  // Activer/désactiver les ads (par exemple en développement)
  static bool get adsEnabled => const bool.fromEnvironment(
        'ADS_ENABLED',
        defaultValue: true,
      );
}

/// Widget de bannière PropellerAds prêt à l'emploi
class PropellerBannerAd extends StatelessWidget {
  final double height;

  const PropellerBannerAd({
    super.key,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) {
    return PropellerAdsBanner(
      zoneId: PropellerAdsConfig.bannerZoneId,
      height: height,
      enabled: PropellerAdsConfig.adsEnabled,
    );
  }
}
