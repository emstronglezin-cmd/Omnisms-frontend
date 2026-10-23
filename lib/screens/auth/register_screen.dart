import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/otp_service.dart';
import '../dashboard_screen.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey                  = GlobalKey<FormState>();
  final _nameController            = TextEditingController();
  final _usernameController        = TextEditingController();
  final _emailController           = TextEditingController();
  final _phoneController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;
  bool _isWakingUp             = false;

  /// Numéro normalisé (E.164) affiché sous le champ avant envoi : c'est
  /// exactement celui que le serveur utilisera pour le SMS.
  String _normalizedPhone = '';

  void _onPhoneChanged(String value) {
    final normalized = PhoneFormatter.normalize(value);
    if (normalized != _normalizedPhone) {
      setState(() {
        _normalizedPhone = PhoneFormatter.isValid(value) ? normalized : '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show wakeup hint after 5s
    final wakeupTimer = Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isWakingUp = true);
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      name:     _nameController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      phone:    _phoneController.text.trim(),
      email:    _emailController.text.trim().isNotEmpty
                  ? _emailController.text.trim()
                  : null,
    );

    await wakeupTimer.catchError((_) {});
    if (mounted) setState(() => _isWakingUp = false);
    if (!mounted) return;

    if (success) {
      // Le serveur exige la vérification du numéro : on ouvre l'écran OTP.
      // La session reste FERMÉE tant que le serveur n'a pas confirmé —
      // le tableau de bord n'est donc pas atteignable ici.
      if (auth.needsPhoneVerification) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OtpVerificationScreen()),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Erreur d\'inscription'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscription'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header ────────────────────────────────
                        Container(
                          width: 64, height: 64,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF0066FF)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 32),
                        ),
                        Text(
                          'Créer un compte',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Rejoignez OmniSMS',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 28),

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
                          const SizedBox(height: 14),
                        ],

                        // ── Wakeup indicator ──────────────────────
                        if (_isWakingUp && auth.isLoading) ...[
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
                                    strokeWidth: 2, color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Démarrage du serveur…\nCela peut prendre jusqu\'à 60 secondes.',
                                    style: TextStyle(
                                      color: Colors.orange.shade700, fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── Name ──────────────────────────────────
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          decoration: InputDecoration(
                            labelText: 'Nom complet',
                            prefixIcon: const Icon(Icons.person_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Nom requis' : null,
                        ),
                        const SizedBox(height: 14),

                        // ── Username (obligatoire côté backend) ───
                        TextFormField(
                          controller: _usernameController,
                          autofillHints: const [AutofillHints.username],
                          decoration: InputDecoration(
                            labelText: "Nom d'utilisateur",
                            hintText: 'monpseudo',
                            prefixIcon: const Icon(Icons.alternate_email),
                            helperText: 'Lettres, chiffres, _ . - (2 à 50)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) {
                              return "Nom d'utilisateur requis";
                            }
                            if (!AuthService.isValidUsername(value)) {
                              return AuthService.usernameHint();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // ── Email (optionnel) ─────────────────────
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: 'Email (optionnel)',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final emailRegex = RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                            if (!emailRegex.hasMatch(v.trim())) {
                              return 'Email invalide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // ── Phone (optional) ──────────────────────
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          onChanged: _onPhoneChanged,
                          decoration: InputDecoration(
                            labelText: 'Téléphone',
                            hintText: '+22670000000',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            helperText: _normalizedPhone.isEmpty
                                ? 'Avec l\'indicatif international (ex: +226…)'
                                : 'Sera enregistré comme : $_normalizedPhone',
                            helperStyle: TextStyle(
                              color: _normalizedPhone.isEmpty
                                  ? null
                                  : const Color(0xFF00D4FF),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Numéro de téléphone requis';
                            }
                            final phoneRegex = RegExp(r'^\+?[0-9\s\-().]{7,20}$');
                            if (!phoneRegex.hasMatch(v.trim())) {
                              return 'Numéro invalide (ex: +22670000000)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // ── Password ──────────────────────────────
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.newPassword],
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
                            if (v.length < 8) return 'Au moins 8 caractères (requis par le serveur)';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // ── Confirm Password ──────────────────────
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirmer le mot de passe',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () =>
                                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Confirmation requise';
                            if (v != _passwordController.text) return 'Mots de passe différents';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── Register button ───────────────────────
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _handleRegister,
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
                                      strokeWidth: 2.5, color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'S\'inscrire',
                                    style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Back to login ─────────────────────────
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Déjà un compte ? Se connecter'),
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
