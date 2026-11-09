import 'package:flutter/material.dart';
import '../theme/omni_design.dart';
import '../theme/omni_motion.dart';
import '../utils/app_version.dart';
import 'auth/login_screen.dart';

/// Écran de démarrage OmniSMS V3.
///
/// La logique de navigation est **volontairement inchangée** : l'écran va
/// toujours vers [LoginScreen], qui effectue la vérification d'authentification
/// en interne. C'est ce choix qui rend le démarrage robuste : aucun fournisseur
/// n'a besoin d'être prêt au moment de l'affichage.
///
/// Ce qui change en V3, c'est la mise en scène :
/// * le logo respire lentement (halo qui pulse) au lieu d'apparaître avec un
///   ressort élastique — un ressort sur un écran de démarrage donne une
///   impression de jouet, pas de produit fini ;
/// * les couleurs viennent du design system ;
/// * la version affichée provient de [AppVersion], gardée par un test qui la
///   compare à `pubspec.yaml` — elle ne peut pas se désynchroniser.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _apparition;
  late AnimationController _halo;
  late Animation<double> _courbeApparition;

  @override
  void initState() {
    super.initState();

    _apparition = AnimationController(
      vsync: this,
      duration: OmniMouvement.expressif,
    )..forward();

    _courbeApparition = CurvedAnimation(
      parent: _apparition,
      curve: OmniMouvement.arrivee,
    );

    // Halo qui respire : une seule animation en boucle sur tout l'écran.
    _halo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // « Animations réduites » : on ne lance pas la boucle, qui est la seule
    // animation réellement susceptible d'incommoder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!OmniMouvement.animationsReduites(context)) {
        _halo.repeat(reverse: true);
      }
    });

    _naviguerVersConnexion();
  }

  @override
  void dispose() {
    _apparition.dispose();
    _halo.dispose();
    super.dispose();
  }

  Future<void> _naviguerVersConnexion() async {
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    try {
      Navigator.of(context).pushReplacement(
        OmniRoute<void>(
          type: OmniTypeTransition.fondu,
          builder: (_) => const LoginScreen(),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Splash navigation error: $e');
      if (mounted) {
        try {
          Navigator.of(context).pushReplacementNamed('/login');
        } catch (e2) {
          debugPrint('⚠️ Fallback navigation error: $e2');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = OmniCouleurs.of(context);

    return Scaffold(
      backgroundColor: OmniPalette.sombreFond,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_apparition, _halo]),
          builder: (context, _) {
            final apparition = _courbeApparition.value;
            final respiration = _halo.value;

            return Opacity(
              opacity: apparition,
              child: Transform.translate(
                offset: Offset(0, (1 - apparition) * 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LogoV3(respiration: respiration, couleurs: c),
                    const SizedBox(height: OmniEspace.xxl),
                    Text(
                      'OmniSMS',
                      style: OmniTypo.display.copyWith(
                        color: OmniPalette.sombreTexte,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: OmniEspace.xs),
                    Text(
                      'Messagerie intelligente',
                      style: OmniTypo.secondaire.copyWith(
                        color: OmniPalette.sombreTexteSecondaire,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: OmniEspace.huge),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(OmniPalette.cyan),
                      ),
                    ),
                    const SizedBox(height: OmniEspace.xxl),
                    // Version issue de la source unique, vérifiée par un
                    // test contre pubspec.yaml.
                    Text(
                      'Version ${AppVersion.complete}',
                      style: OmniTypo.micro.copyWith(
                        color: OmniPalette.sombreTexteEstompe,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Logo V3 : dégradé de marque + halo qui respire.
///
/// Le halo matérialise l'activité réseau de démarrage sans ajouter de texte
/// ni de deuxième animation : c'est le seul mouvement de l'écran, et il est
/// lent (2,2 s) pour rester apaisant.
class _LogoV3 extends StatelessWidget {
  const _LogoV3({required this.respiration, required this.couleurs});

  /// Valeur 0→1 de la respiration.
  final double respiration;

  final OmniCouleurs couleurs;

  @override
  Widget build(BuildContext context) {
    // Le halo varie de 0,18 à 0,34 d'opacité et de 28 à 44 dp de flou :
    // amplitude faible, perceptible sans attirer l'œil plus que le logo.
    final opacite = 0.18 + respiration * 0.16;
    final flou = 28.0 + respiration * 16;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: couleurs.degradeAccent,
        borderRadius: BorderRadius.circular(OmniRayon.xl),
        boxShadow: [
          BoxShadow(
            color: OmniPalette.cyan.withValues(alpha: opacite),
            blurRadius: flou,
            spreadRadius: 2 + respiration * 3,
          ),
        ],
      ),
      child: const Icon(
        Icons.sms_rounded,
        size: 60,
        color: Colors.white,
      ),
    );
  }
}
