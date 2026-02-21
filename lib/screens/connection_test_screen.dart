import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connection_test_service.dart';
import '../config/app_theme.dart';

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  final ConnectionTestService _testService = ConnectionTestService();
  Map<String, dynamic>? _results;
  bool _isTesting = false;

  Future<void> _runTests() async {
    setState(() {
      _isTesting = true;
      _results = null;
    });

    final results = await _testService.runAllTests();

    if (mounted) {
      setState(() {
        _results = results;
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Test de connexion',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.darkBackgroundGradient
              : AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_sync,
                        size: 64,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Test de connexion backend',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vérifiez que votre backend est accessible',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: -0.2, end: 0),

                const SizedBox(height: 24),

                // Bouton de test
                ElevatedButton(
                  onPressed: _isTesting ? null : _runTests,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isTesting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Test en cours...',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow),
                            const SizedBox(width: 8),
                            Text(
                              'Lancer les tests',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.8, 0.8)),

                const SizedBox(height: 24),

                // Résultats des tests
                if (_results != null) ...[
                  _buildResultsSection(isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection(bool isDark) {
    final allSuccess = _results!.values.every((result) => result['success'] == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Résumé global
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: allSuccess
                ? AppTheme.successColor.withOpacity(0.1)
                : AppTheme.errorColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: allSuccess
                  ? AppTheme.successColor.withOpacity(0.3)
                  : AppTheme.errorColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: allSuccess
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  allSuccess ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allSuccess ? 'Tous les tests réussis' : 'Tests échoués',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: allSuccess
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allSuccess
                          ? 'Backend accessible et fonctionnel'
                          : 'Certains endpoints ne répondent pas',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.95, 0.95)),

        const SizedBox(height: 16),

        // Détails des tests
        ...(_results!.entries.map((entry) {
          final testName = entry.key;
          final result = entry.value;
          final success = result['success'] as bool;
          final message = result['message'] as String;
          final duration = result['duration'] as int?;

          return _buildTestCard(
            testName,
            success,
            message,
            duration,
            isDark,
          );
        })),
      ],
    );
  }

  Widget _buildTestCard(
    String testName,
    bool success,
    String message,
    int? duration,
    bool isDark,
  ) {
    final testTitles = {
      'contacts': 'API Contacts',
      'messages': 'API Messages',
      'sendMessage': 'Envoi de messages',
      'websocket': 'WebSocket temps réel',
    };

    final testIcons = {
      'contacts': Icons.contacts,
      'messages': Icons.message,
      'sendMessage': Icons.send,
      'websocket': Icons.wifi,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: success
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.errorColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: success
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              testIcons[testName] ?? Icons.api,
              color: success ? AppTheme.successColor : AppTheme.errorColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  testTitles[testName] ?? testName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: success
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ),
                if (duration != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${duration}ms',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withOpacity(0.4)
                          : Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            success ? Icons.check_circle : Icons.cancel,
            color: success ? AppTheme.successColor : AppTheme.errorColor,
            size: 28,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideX(begin: 0.2, end: 0);
  }
}
