import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/omni_design.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../services/otp_service.dart';
import '../dashboard_screen.dart';

/// Écran de saisie du code OTP reçu par SMS.
///
/// Règles respectées :
///   • le code n'est JAMAIS conservé : il vit dans le champ de saisie et
///     n'est transmis qu'au serveur (aucune préférence, aucun journal) ;
///   • retour arrière bloqué ([PopScope]) — on ne rejoint pas l'écran
///     principal sans confirmation du serveur ;
///   • une seule soumission à la fois (garde locale + garde du provider) ;
///   • le renvoi respecte le délai serveur (`OTP_COOLDOWN`) ;
///   • toutes les erreurs serveur sont affichées telles quelles (code faux,
///     expiré, trop de tentatives, service indisponible, réseau).
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _cooldownTimer;
  bool _initialSendDone = false;
  bool _submitting = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // Envoi automatique du premier code, UNE seule fois par écran.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendInitialCode());
  }

  @override
  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    // Le code ne survit pas à l'écran.
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendInitialCode() async {
    if (_initialSendDone || _disposed || !mounted) return;
    _initialSendDone = true;

    final auth = context.read<AuthProvider>();
    final result = await auth.resendOtp();
    if (!mounted) return;

    if (result.ok) {
      _startCooldownTimer();
      FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || !mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.otpResendCooldown <= 0) {
        _cooldownTimer?.cancel();
        return;
      }
      auth.tickOtpCooldown();
    });
  }

  /// Soumission — gardée contre les doubles appels (auto-submit + bouton).
  Future<void> _submit() async {
    if (_submitting) return;
    final code = _codeController.text.trim();
    if (code.length != ApiConfig.otpCodeLength) {
      setState(() => _submitting = false);
      _showLocalError('Saisissez les ${ApiConfig.otpCodeLength} chiffres du code.');
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();

    final ok = await auth.verifyOtp(code);
    if (!mounted) return;

    setState(() => _submitting = false);

    if (ok) {
      // Vérification confirmée PAR LE SERVEUR : la session est ouverte ici,
      // et seulement ici.
      _codeController.clear();
      // Même convention que l'écran de connexion : réinitialise la messagerie
      // maintenant que le jeton est enregistré (évite un 401 au premier appel).
      try {
        context.read<MessagingProvider>().reinitialize();
      } catch (_) {}
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
      return;
    }

    // Échec : le code reste pour permettre la correction, sauf si le serveur
    // a révoqué le code (expiré / trop de tentatives) — on le vide alors.
    final failure = auth.otpFailure;
    if (failure == OtpFailure.expired ||
        failure == OtpFailure.tooManyAttempts ||
        failure == OtpFailure.noPendingCode) {
      _codeController.clear();
      // Le compte à rebours de renvoi continue de courir.
    }
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _showLocalError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: OmniPalette.avertissement,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    if (auth.isResendingOtp || auth.otpResendCooldown > 0) return;

    _codeController.clear();
    final result = await auth.resendOtp();
    if (!mounted) return;

    _startCooldownTimer();
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: OmniPalette.succes,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changeNumber() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Modifier le numéro ?'),
            content: const Text(
              "Le code envoyé ne sera plus valable. Vous pourrez recommencer "
              "l'inscription avec un autre numéro.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Modifier'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    await context.read<AuthProvider>().cancelVerification();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      // Retour système bloqué : la vérification ne se contourne pas.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vérification'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final pending = auth.pendingVerification;
              if (pending == null) {
                // Aucune vérification en cours : retour immédiat.
                return const Center(child: CircularProgressIndicator());
              }

              final canResend = auth.otpResendCooldown <= 0 && !auth.isResendingOtp;
              final resendLabel = auth.otpResendCooldown > 0
                  ? 'Renvoyer un code dans ${auth.otpResendCooldown} s'
                  : (auth.isResendingOtp ? 'Envoi en cours…' : 'Renvoyer un code');

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── En-tête ─────────────────────────────────
                        Container(
                          width: 64,
                          height: 64,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: OmniCouleurs.of(context).degradeAccent,
                            borderRadius: OmniRayon.carte,
                          ),
                          child: Icon(Icons.sms_rounded,
                              color: OmniCouleurs.of(context).surAccent, size: 32),
                        ),
                        Text(
                          'Vérifiez votre numéro',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Un code à ${ApiConfig.otpCodeLength} chiffres a été envoyé par SMS au ${pending.phone}.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // ── Saisie du code ──────────────────────────
                        Semantics(
                          label: 'Code de vérification à ${ApiConfig.otpCodeLength} chiffres',
                          child: TextField(
                            controller: _codeController,
                            focusNode: _focusNode,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              letterSpacing: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: ApiConfig.otpCodeLength,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              counterText: '',
                              hintText: '——————',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                            onChanged: (value) {
                              // Efface l'erreur serveur dès que l'utilisateur
                              // corrige sa saisie.
                              if (auth.otpError != null) auth.clearOtpError();
                              if (value.length == ApiConfig.otpCodeLength) {
                                _submit();
                              }
                            },
                            onSubmitted: (_) => _submit(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Erreur serveur ──────────────────────────
                        if (auth.otpError != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: OmniPalette.erreur.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: OmniPalette.erreur.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: OmniPalette.erreur, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.otpError!,
                                    style: TextStyle(color: OmniPalette.erreur),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (auth.otpError != null) const SizedBox(height: 16),

                        // ── Bouton de vérification ──────────────────
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed:
                                (_submitting || auth.isVerifyingOtp) ? null : _submit,
                            child: (_submitting || auth.isVerifyingOtp)
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Vérifier'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Renvoi ──────────────────────────────────
                        TextButton(
                          onPressed: canResend ? _resend : null,
                          child: Text(resendLabel),
                        ),

                        // ── Modifier le numéro ──────────────────────
                        TextButton(
                          onPressed: _changeNumber,
                          child: const Text('Modifier le numéro'),
                        ),

                        const SizedBox(height: 8),
                        Text(
                          "Le code est valable ${ApiConfig.otpValiditySeconds ~/ 60} minutes. "
                          'Ne le communiquez à personne.',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
