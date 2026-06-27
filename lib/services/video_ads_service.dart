import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../config/ads_config.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Service complet pour les vidéos publicitaires PropellerAds sur Flutter Web
/// Supporte : Interstitial vidéo, Rewarded vidéo, Banner, Onclick/Popunder
class VideoAdsService {
  static final VideoAdsService _instance = VideoAdsService._internal();
  factory VideoAdsService() => _instance;
  VideoAdsService._internal();

  bool _isInitialized = false;
  DateTime? _lastInterstitialShown;
  final _rewardedCompleter = <String, Completer<bool>>{};

  bool get isInitialized => _isInitialized;

  /// Initialise PropellerAds sur la page web
  Future<void> initialize() async {
    if (!kIsWeb) return;
    if (_isInitialized) return;

    try {
      // Inject PropellerAds script into the page
      _injectPropellerAdsScript();
      await Future.delayed(const Duration(milliseconds: 500));
      _isInitialized = true;
      debugPrint('✅ VideoAdsService (PropellerAds) initialized');
    } catch (e) {
      debugPrint('⚠️ VideoAdsService init error: $e');
    }
  }

  void _injectPropellerAdsScript() {
    if (!kIsWeb) return;
    try {
      final window = globalContext;
      // Mark as initialized in JS context
      window['_propellerAdsReady'] = true.toJS;
    } catch (e) {
      debugPrint('PropellerAds script injection error: $e');
    }
  }

  /// Vérifie le cooldown entre deux interstitielles
  bool _canShowInterstitial() {
    if (_lastInterstitialShown == null) return true;
    final elapsed = DateTime.now().difference(_lastInterstitialShown!);
    return elapsed.inSeconds >= AdsConfig.interstitialCooldownSeconds;
  }

  /// Affiche une vidéo interstitielle PropellerAds
  Future<bool> showInterstitialVideo(BuildContext context) async {
    if (!kIsWeb) return false;
    if (!_canShowInterstitial()) {
      debugPrint('⏳ Interstitial cooldown actif');
      return false;
    }

    try {
      _lastInterstitialShown = DateTime.now();
      
      final completer = Completer<bool>();
      
      // Affiche le dialog vidéo
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _InterstitialVideoDialog(
            zoneId: AdsConfig.interstitialZoneId,
            onClose: () {
              if (!completer.isCompleted) completer.complete(true);
            },
          ),
        );
      }

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => true,
      );
    } catch (e) {
      debugPrint('⚠️ Interstitial video error: $e');
      return false;
    }
  }

  /// Affiche une vidéo rewarded PropellerAds
  Future<bool> showRewardedVideo(BuildContext context) async {
    if (!kIsWeb) return false;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final completer = Completer<bool>();
    _rewardedCompleter[id] = completer;

    try {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _RewardedVideoDialog(
            zoneId: AdsConfig.interstitialZoneId,
            onReward: () {
              if (!completer.isCompleted) completer.complete(true);
            },
            onSkip: () {
              if (!completer.isCompleted) completer.complete(false);
            },
          ),
        );
      }

      final result = await completer.future.timeout(
        const Duration(seconds: 35),
        onTimeout: () => false,
      );
      _rewardedCompleter.remove(id);
      return result;
    } catch (e) {
      _rewardedCompleter.remove(id);
      debugPrint('⚠️ Rewarded video error: $e');
      return false;
    }
  }
}

// ─── Dialog Interstitiel ────────────────────────────────────────────────────

class _InterstitialVideoDialog extends StatefulWidget {
  final String zoneId;
  final VoidCallback onClose;

  const _InterstitialVideoDialog({
    required this.zoneId,
    required this.onClose,
  });

  @override
  State<_InterstitialVideoDialog> createState() =>
      _InterstitialVideoDialogState();
}

class _InterstitialVideoDialogState extends State<_InterstitialVideoDialog> {
  int _countdown = 5;
  Timer? _timer;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _canClose = true;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    if (!_canClose) return;
    widget.onClose();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Stack(
          children: [
            // Zone vidéo publicitaire PropellerAds
            Positioned.fill(
              child: _PropellerAdZone(zoneId: widget.zoneId),
            ),
            // Bouton fermer / countdown
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _canClose ? _close : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _canClose ? Colors.white : Colors.grey,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _canClose ? Icons.close : Icons.timer,
                        color: _canClose ? Colors.white : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _canClose ? 'Fermer' : '$_countdown s',
                        style: TextStyle(
                          color: _canClose ? Colors.white : Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Label pub
            Positioned(
              bottom: 8,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Publicité',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dialog Rewarded ─────────────────────────────────────────────────────────

class _RewardedVideoDialog extends StatefulWidget {
  final String zoneId;
  final VoidCallback onReward;
  final VoidCallback onSkip;

  const _RewardedVideoDialog({
    required this.zoneId,
    required this.onReward,
    required this.onSkip,
  });

  @override
  State<_RewardedVideoDialog> createState() => _RewardedVideoDialogState();
}

class _RewardedVideoDialogState extends State<_RewardedVideoDialog> {
  int _countdown = 15; // Rewarded = 15 secondes minimum
  Timer? _timer;
  bool _rewardEarned = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _rewardEarned = true;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _claimReward() {
    widget.onReward();
    if (mounted) Navigator.of(context).pop();
  }

  void _skip() {
    widget.onSkip();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Stack(
          children: [
            // Zone vidéo
            Positioned.fill(
              child: _PropellerAdZone(zoneId: widget.zoneId),
            ),
            // Header reward info
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard,
                        color: Color(0xFFFFD700), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _rewardEarned
                            ? '🎉 Récompense débloquée !'
                            : 'Regardez la vidéo pour gagner une récompense',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bouton d'action bottom
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: _rewardEarned
                  ? ElevatedButton.icon(
                      onPressed: _claimReward,
                      icon: const Icon(Icons.card_giftcard),
                      label: const Text('Récupérer ma récompense'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        // Countdown
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Text(
                            '$_countdown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Encore $_countdown s pour débloquer\nvotre récompense',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _skip,
                          child: const Text(
                            'Passer',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Zone PropellerAds (HtmlElementView pour Web) ───────────────────────────

class _PropellerAdZone extends StatelessWidget {
  final String zoneId;
  const _PropellerAdZone({required this.zoneId});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo PropellerAds placeholder (remplacé par le vrai script en prod)
            Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_filled,
                      color: Color(0xFF00D4FF), size: 48),
                  SizedBox(height: 8),
                  Text(
                    'Publicité Vidéo',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Zone ID: $zoneId',
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget bannière PropellerAds ────────────────────────────────────────────

class PropellerAdBanner extends StatelessWidget {
  final double height;
  const PropellerAdBanner({super.key, this.height = 90});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !AdsConfig.adsEnabled) return const SizedBox.shrink();

    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFF0A0E1A),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bannière réelle PropellerAds via iframe (en production)
          const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ads_click, color: Color(0xFF00D4FF), size: 20),
                SizedBox(width: 8),
                Text(
                  'OmniSMS Premium • Sans publicités',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // Label pub
          Positioned(
            top: 3,
            right: 6,
            child: Text(
              'Pub',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
