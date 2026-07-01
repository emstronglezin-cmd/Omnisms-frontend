import 'package:flutter/material.dart';
import 'auth/login_screen.dart';

/// Splash screen with bulletproof navigation.
/// Always navigates to LoginScreen — auth check happens inside LoginScreen.
/// This avoids any crash from providers that might not be ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();
    _navigateToLogin();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _navigateToLogin() async {
    // Wait for splash animation + a short delay
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    try {
      // Always go to LoginScreen — it handles auth check internally
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Splash navigation error: $e');
      // Fallback: try named route
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
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00D4FF), Color(0xFF0066FF)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(0.4),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sms_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // App name
              const Text(
                'OmniSMS',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Messagerie intelligente',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 56),
              // Spinner
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF00D4FF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
