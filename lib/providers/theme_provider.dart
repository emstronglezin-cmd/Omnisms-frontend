import 'package:flutter/material.dart';

import '../theme/omni_design.dart';
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

  /// Variante visuelle active. « Classique » reste le défaut : une nouvelle
  /// identité ne remplace jamais l'ancienne sans être choisie.
  // V4 approuvée par l'utilisateur : le NOUVEAU frontend est le défaut.
  // L'identité d'origine reste selectable in one gesture in the settings, and
  // it is rendered identically (capture: 0.00% pixel difference).
  OmniVariante _variante = OmniVariante.nova;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await _settingsService.getThemeMode();
    _themeMode = _parseThemeMode(theme);
    _variante = _parseVariante(await _settingsService.getVariante());
    notifyListeners();
  }

  /// Variante visuelle courante.
  OmniVariante get variante => _variante;

  /// Change de variante visuelle. Toute l'interface est reconstruite : aucun
  /// écran ne connaît la variante, ils lisent tous les jetons du thème.
  Future<void> setVariante(OmniVariante variante) async {
    if (variante == _variante) return;
    _variante = variante;
    await _settingsService.setVariante(_varianteToString(variante));
    notifyListeners();
  }

  OmniVariante _parseVariante(String valeur) {
    return switch (valeur.toLowerCase()) {
      'nova' => OmniVariante.nova,
      _ => OmniVariante.classique, // l'identité d'origine reste le repli
    };
  }

  String _varianteToString(OmniVariante variante) {
    return switch (variante) {
      OmniVariante.nova => 'nova',
      OmniVariante.classique => 'classique',
    };
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

  /// Thème clair, dans la variante courante.
  ThemeData get lightTheme => switch (_variante) {
        OmniVariante.nova => OmniTheme.novaClair(),
        OmniVariante.classique => OmniTheme.clair(),
      };

  /// Thème sombre (par défaut d'OmniSMS), dans la variante courante.
  ThemeData get darkTheme => switch (_variante) {
        OmniVariante.nova => OmniTheme.novaSombre(),
        OmniVariante.classique => OmniTheme.sombre(),
      };
}
