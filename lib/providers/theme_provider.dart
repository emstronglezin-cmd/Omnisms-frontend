import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../theme/omni_theme.dart';

// ─── OmniSMS Brand Colors ──────────────────────────────────────────────────────
class OmniColors {
  OmniColors._();

  // Primary brand
  static const Color bgPrimary   = Color(0xFF08090F);
  static const Color bgSecondary = Color(0xFF0E1118);
  static const Color bgCard      = Color(0xFF141720);
  static const Color bgCard2     = Color(0xFF1A1E2E);
  static const Color bgInput     = Color(0xFF1E2232);

  // Accent
  static const Color accent      = Color(0xFF00C8FF); // cyan électrique
  static const Color accent2     = Color(0xFF0057FF); // deep blue
  static const Color accentGlow  = Color(0x4D00C8FF); // 30% opacity

  // Text
  static const Color textPrimary   = Color(0xFFE4EAF5);
  static const Color textSecondary = Color(0xFF6B7A96);
  static const Color textMuted     = Color(0xFF3A4557);

  // Semantic
  static const Color success = Color(0xFF00E676);
  static const Color error   = Color(0xFFFF4565);
  static const Color warning = Color(0xFFFFB020);

  // Glass surfaces
  static const Color glassBg      = Color(0xB80E1118); // rgba(14,17,24,0.72)
  static const Color glassBorder  = Color(0x17FFFFFF); // rgba(255,255,255,0.09)

  // Gradients
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent2],
  );
}

class ThemeProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  ThemeMode _themeMode = ThemeMode.dark; // OmniSMS est dark-first

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await _settingsService.getThemeMode();
    _themeMode = _parseThemeMode(theme);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _settingsService.setThemeMode(_themeModeToString(mode));
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.dark; // dark par défaut pour OmniSMS
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'dark';
    }
  }

  // ── Thèmes ─────────────────────────────────────────────────────────────────
  // Délégués au design system (`lib/theme/omni_theme.dart`), qui construit des
  // thèmes Material 3 complets à partir des jetons `omni_design.dart` :
  // couleurs, typographie, rayons, boutons, champs, cartes, navigation.
  // Les deux thèmes sont désormais de qualité égale — le mode clair n'est plus
  // une « version allégée » du mode sombre.

  /// Thème clair.
  static ThemeData get lightTheme => OmniTheme.clair();

  /// Thème sombre (thème par défaut d'OmniSMS).
  static ThemeData get darkTheme => OmniTheme.sombre();
}
