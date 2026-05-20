/// Configuration des publicités PropellerAds pour OmniSMS
class AdsConfig {
  // ==================== PropellerAds Zone IDs ====================
  // Remplacez ces valeurs par vos vrais Zone IDs depuis PropellerAds dashboard
  
  /// Banner Ad Zone ID - Format bannière standard
  static const String bannerZoneId = 'REPLACE_WITH_YOUR_BANNER_ZONE_ID';
  
  /// Interstitial Ad Zone ID - Format plein écran
  static const String interstitialZoneId = 'REPLACE_WITH_YOUR_INTERSTITIAL_ZONE_ID';
  
  /// Push Notification Zone ID - Format push notifications
  static const String pushNotificationZoneId = 'REPLACE_WITH_YOUR_PUSH_ZONE_ID';
  
  /// Onclick (Popunder) Zone ID - Format onclick/popunder
  static const String onclickZoneId = 'REPLACE_WITH_YOUR_ONCLICK_ZONE_ID';
  
  // ==================== Configuration ====================
  
  /// Activer/désactiver toutes les publicités
  /// Peut être contrôlé par variable d'environnement: flutter build --dart-define=ADS_ENABLED=false
  static bool get adsEnabled => const bool.fromEnvironment(
        'ADS_ENABLED',
        defaultValue: true, // true en production, false en développement
      );
  
  /// Délai minimum entre deux affichages d'interstitielles (en secondes)
  static const int interstitialCooldownSeconds = 60;
  
  /// Afficher des ads sur les pages spécifiques
  static const bool showAdsOnDashboard = true;
  static const bool showAdsOnContacts = true;
  static const bool showAdsOnGroups = true;
  static const bool showAdsOnConversation = false; // Ne pas déranger pendant les conversations
  
  /// Hauteur des bannières (en pixels)
  static const double bannerHeightMobile = 90.0;
  static const double bannerHeightTablet = 120.0;
  static const double bannerHeightWeb = 100.0;
  
  // ==================== Méthodes utilitaires ====================
  
  /// Obtenir la hauteur de bannière selon le device
  static double getBannerHeight(double screenWidth) {
    if (screenWidth >= 1200) {
      return bannerHeightWeb;
    } else if (screenWidth >= 600) {
      return bannerHeightTablet;
    } else {
      return bannerHeightMobile;
    }
  }
  
  /// Vérifier si les Zone IDs sont configurés
  static bool get isConfigured {
    return bannerZoneId != 'REPLACE_WITH_YOUR_BANNER_ZONE_ID' &&
           bannerZoneId.isNotEmpty;
  }
  
  /// Message d'avertissement si non configuré
  static String get configWarning {
    return 'PropellerAds n\'est pas configuré. '
           'Veuillez remplacer les Zone IDs dans lib/config/ads_config.dart '
           'avec vos vrais Zone IDs depuis votre dashboard PropellerAds.';
  }
}

/// Instructions d'intégration PropellerAds
/// 
/// 1. Créer un compte sur https://propellerads.com/
/// 
/// 2. Ajouter votre application/site web
/// 
/// 3. Créer des zones publicitaires (Ad Zones):
///    - Banner: Pour bannières standard
///    - Interstitial: Pour ads plein écran
///    - Push: Pour notifications push
///    - Onclick: Pour popunders
/// 
/// 4. Copier les Zone IDs et les coller ci-dessus
/// 
/// 5. Tester les ads en mode développement:
///    - Activer test mode dans PropellerAds dashboard
///    - Vérifier que les ads s'affichent correctement
/// 
/// 6. Déployer en production:
///    - Désactiver test mode
///    - Vérifier que adsEnabled = true
///    - Surveiller les performances dans PropellerAds dashboard
