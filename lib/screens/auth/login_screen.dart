import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth/google_sign_in_button.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';
import '../dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController   = TextEditingController();
  bool _obscurePassword = true;
  bool _isWakingUp      = false; // Render free tier wakeup indicator

  /// L'identifiant est un numéro de téléphone dès qu'il ne contient pas de « @ ».
  /// Même heuristique que la PWA : /^[+\d\s\-()+]{7,20}$/ et pas de « @ ».
  bool get _looksLikePhone => AuthService.isPhoneIdentifier(_identifierController.text);

  @override
  void initState() {
    super.initState();
    // CORRECTION race condition (Session 9) :
    // addPostFrameCallback s'exécute après le premier frame, mais
    // AuthProvider._checkLoginStatus() est async. Sur Safari iOS, le
    // SharedPreferences.getInstance() peut ne pas avoir fini au premier frame.
    //
    // Stratégie : vérifier auth.isLoading avant de naviguer.
    // Si isLoading est true → attendre la fin via addListener.
    // Si isLoading est false → décider immédiatement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final auth = context.read<AuthProvider>();
        if (auth.isLoading) {
          // Auth pas encore prête → attendre la fin du chargement
          void onAuthChanged() {
            if (!mounted) return;
            if (!auth.isLoading) {
              auth.removeListener(onAuthChanged);
              if (!mounted) return;
              if (auth.needsPhoneVerification) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => const OtpVerificationScreen()),
                );
              } else if (auth.isLoggedIn) {
                try {
                  context.read<MessagingProvider>().reinitialize();
                } catch (_) {}
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              }
            }
          }
          auth.addListener(onAuthChanged);
        } else if (auth.needsPhoneVerification) {
          // Vérification laissée en suspens (application fermée pendant le
          // parcours) : on la reprend avant tout.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OtpVerificationScreen()),
          );
        } else if (auth.isLoggedIn) {
          try {
            context.read<MessagingProvider>().reinitialize();
          } catch (_) {}
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } catch (e) {
        debugPrint('⚠️ Auth check: $e');
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Show wakeup hint after 5s (Render free tier can be slow)
    final wakeupTimer = Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isWakingUp = true);
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      identifier: _identifierController.text.trim(),
      password: _passwordController.text,
    );

    await wakeupTimer.catchError((_) {});
    if (mounted) setState(() => _isWakingUp = false);
    if (!mounted) return;

    if (success) {
      // Compte existant dont le numéro n'est pas vérifié : le serveur le
      // signale, on reprend le parcours de vérification.
      if (auth.needsPhoneVerification) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OtpVerificationScreen()),
        );
        return;
      }

      // CORRECTION race condition (Session 9) :
      // Déclencher reinitialize() sur MessagingProvider maintenant que le token
      // est confirmé dans SharedPreferences. Évite le 401 sur /conversations.
      try {
        context.read<MessagingProvider>().reinitialize();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
      // Comme la PWA : un compte sans numéro de téléphone (vieux compte Google
      // ou email) doit compléter son profil — le backend a besoin du numéro
      // pour router les SMS.
      final user = auth.currentUser;
      if (user != null && (user.needsPhone || (user.phone?.isEmpty ?? true))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ Merci d'ajouter votre numéro de téléphone dans Paramètres.",
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Erreur de connexion'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Connexion Google — le flux complet (navigateur → Google → deep link →
  /// échange du code) est géré par AuthProvider/AuthService.
  Future<void> _handleGoogleLogin() async {
    final auth = context.read<AuthProvider>();
    // Double protection contre les doubles clics (le bouton est aussi désactivé).
    if (auth.isBusy) return;

    auth.clearError();

    // Indice « serveur en démarrage » comme pour le login classique.
    final wakeupTimer = Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isWakingUp = true);
    });

    final success = await auth.loginWithGoogle();

    await wakeupTimer.catchError((_) {});
    if (mounted) setState(() => _isWakingUp = false);
    if (!mounted) return;

    if (success) {
      // Nouveau compte Google (ou compte existant non vérifié) : le serveur
      // décide si la vérification du numéro est requise.
      if (auth.needsPhoneVerification) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OtpVerificationScreen()),
        );
        return;
      }

      try {
        context.read<MessagingProvider>().reinitialize();
      } catch (_) {}
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
      return;
    }

    // Message utilisateur simple : ni stack trace, ni détail OAuth, ni token.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.error ?? 'Impossible de se connecter avec Google.'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Logo ──────────────────────────────────
                        Container(
                          width: 80, height: 80,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF0066FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.sms_rounded, color: Colors.white, size: 40),
                        ),
                        Text(
                          'OmniSMS',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Messagerie Sécurisée',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ── Error banner ──────────────────────────
                        if (auth.error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Text(
                              auth.error!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Wakeup indicator ──────────────────────
                        if (_isWakingUp && auth.isBusy) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Démarrage du serveur en cours…\nCela peut prendre jusqu\'à 60 secondes.',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── Email ou téléphone ────────────────────
                        TextFormField(
                          controller: _identifierController,
                          keyboardType: _looksLikePhone
                              ? TextInputType.phone
                              : TextInputType.emailAddress,
                          autofillHints: _looksLikePhone
                              ? const [AutofillHints.telephoneNumber]
                              : const [AutofillHints.email],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Email ou téléphone',
                            hintText: 'vous@email.com ou +22670123456',
                            prefixIcon: Icon(_looksLikePhone
                                ? Icons.phone_outlined
                                : Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Email ou téléphone requis';
                            if (AuthService.isPhoneIdentifier(value)) {
                              if (value.replaceAll(RegExp(r'[^\d]'), '').length < 7) {
                                return 'Numéro de téléphone invalide';
                              }
                              return null;
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Email invalide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Password ──────────────────────────────
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Mot de passe requis';
                            if (v.length < 6) return 'Au moins 6 caractères';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── Login button ──────────────────────────
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.isBusy ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0066FF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 22, width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Se connecter',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Google sign-in ────────────────────────
                        GoogleSignInButton(
                          isLoading: auth.isGoogleSignInInProgress,
                          enabled: !auth.isBusy,
                          onPressed: _handleGoogleLogin,
                        ),
                        const SizedBox(height: 16),

                        // ── Register link ─────────────────────────
                        const Center(child: Text('ou', style: TextStyle(color: Colors.grey))),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          ),
                          child: const Text('Pas de compte ? S\'inscrire'),
                        ),

                        // ── Guest mode ────────────────────────────
                        TextButton(
                          onPressed: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const DashboardScreen()),
                          ),
                          child: const Text(
                            'Continuer sans compte',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Bouton « Continuer avec Google » — reprend le style des boutons existants
/// (hauteur 52, coins arrondis 12) avec la charte Google.
