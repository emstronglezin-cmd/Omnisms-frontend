/// OmniSMS — Ads Service (Start.io)
/// Phase 4 : Intégration publicitaire Android
///
/// RÈGLE ABSOLUE :
///   - Utilisateurs GRATUITS  → publicités activées
///   - Utilisateurs PREMIUM   → publicités désactivées
///
/// ⚠️  CONFIGURATION REQUISE AVANT PRODUCTION :
///   Remplacer YOUR_START_IO_APP_ID par l'App ID fourni par Start.io dashboard.
///   Obtenir votre App ID sur : https://portal.start.io/

library;

import 'dart:io';
import 'package:flutter/foundation.dart';

// Start.io SDK — Android only, web/iOS non supportés
// ignore: depend_on_referenced_packages
import 'package:startapp_sdk/startapp.dart';

// ─── Configuration ────────────────────────────────────────────────────────────
/// Remplacer par votre App ID Start.io réel
/// Obtenu sur https://portal.start.io/ après enregistrement de votre app
const String _kStartIoAppId = 'YOUR_START_IO_APP_ID';

/// Mode test — mettre à false uniquement en production
const bool _kTestMode = true;

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  bool _initialized = false;
  bool _isPremium = false;

  /// Indique si les publicités sont supportées sur cette plateforme
  bool get _isSupported => !kIsWeb && Platform.isAndroid;

  /// Mettre à jour le statut Premium (appelé au login et à chaque vérification)
  void setPremiumStatus(bool premium) {
    _isPremium = premium;
    debugPrint('[Ads] Premium status: $_isPremium — ads ${_isPremium ? "disabled" : "enabled"}');
  }

  /// Initialiser le SDK Start.io
  /// Appeler depuis main.dart après le login ou au démarrage
  Future<void> initialize() async {
    if (_initialized || !_isSupported) return;

    try {
      await StartAppSdk().setTestAdsEnabled(_kTestMode);
      // Le SDK s'initialise automatiquement avec l'App ID dans AndroidManifest.xml
      // Voir : android/app/src/main/AndroidManifest.xml (à configurer)
      _initialized = true;
      debugPrint('[Ads] Start.io SDK initialized (test: $_kTestMode)');
    } catch (e) {
      debugPrint('[Ads] Start.io init failed: $e');
    }
  }

  /// Charger une bannière publicitaire
  /// Retourne null si premium ou non supporté
  Future<StartAppBanner?> loadBanner() async {
    if (!_isSupported || _isPremium || !_initialized) return null;

    try {
      final banner = StartAppBanner(type: BannerType.banner);
      final result = await banner.load();
      if (result) {
        debugPrint('[Ads] Banner loaded');
        return banner;
      }
    } catch (e) {
      debugPrint('[Ads] Banner load failed: $e');
    }
    return null;
  }

  /// Charger et afficher une interstitielle
  /// NE PAS appeler pendant la rédaction ou l'envoi d'un message
  Future<bool> showInterstitial() async {
    if (!_isSupported || _isPremium || !_initialized) return false;

    try {
      final interstitial = StartAppInterstitial();
      final loaded = await interstitial.load();
      if (loaded) {
        final shown = await interstitial.show();
        debugPrint('[Ads] Interstitial shown: $shown');
        return shown;
      }
    } catch (e) {
      debugPrint('[Ads] Interstitial failed: $e');
    }
    return false;
  }

  /// Vérifier si les publicités sont actives pour cet utilisateur
  bool get adsEnabled => _isSupported && !_isPremium && _initialized;
}

// ─── Widget BannerAdWidget ────────────────────────────────────────────────────
/// Widget bannière publicitaire à placer dans les écrans
/// S'affiche uniquement pour les utilisateurs gratuits sur Android
/// Usage : BannerAdWidget() — à placer hors des zones de saisie
import 'package:flutter/material.dart';

class BannerAdWidget extends StatefulWidget {
  /// Position de la bannière (préférer le bas des listes, jamais dans la conversation)
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  StartAppBanner? _banner;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    final banner = await AdsService().loadBanner();
    if (mounted) {
      setState(() {
        _banner = banner;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sur le web ou iOS : widget vide invisible
    if (kIsWeb || !Platform.isAndroid) return const SizedBox.shrink();
    // Utilisateur premium : widget vide invisible
    if (!AdsService().adsEnabled) return const SizedBox.shrink();
    // Chargement en cours
    if (_loading) return const SizedBox(height: 50);
    // Pas de bannière disponible
    if (_banner == null) return const SizedBox.shrink();

    return Container(
      height: 50,
      color: Colors.transparent,
      child: StartAppBannerAd(banner: _banner!),
    );
  }
}
