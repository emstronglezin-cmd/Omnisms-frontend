import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';

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

  // ── LIGHT THEME (mode clair — version allégée OmniSMS) ──────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: OmniColors.accent,  // OmniSMS cyan au lieu d'Indigo
      brightness: Brightness.light,
      primary: OmniColors.accent,
      secondary: OmniColors.accent2,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: OmniColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),
  );

  // ── DARK THEME (mode sombre — thème principal OmniSMS) ──────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: OmniColors.bgPrimary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: OmniColors.accent,    // OmniSMS cyan
      brightness: Brightness.dark,
      primary:    OmniColors.accent,
      secondary:  OmniColors.accent2,
      surface:    OmniColors.bgCard,
      onSurface:  OmniColors.textPrimary,
      error:      OmniColors.error,
    ),

    // ─── AppBar ─────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: OmniColors.bgSecondary,
      foregroundColor: OmniColors.textPrimary,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: OmniColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: OmniColors.bgSecondary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      iconTheme: IconThemeData(color: OmniColors.accent),
    ),

    // ─── Navigation Bar ─────────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: OmniColors.bgSecondary,
      indicatorColor: Color(0x2200C8FF), // accent à 13%
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: OmniColors.accent,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          );
        }
        return const TextStyle(
          color: OmniColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: OmniColors.accent, size: 24);
        }
        return const IconThemeData(color: OmniColors.textMuted, size: 22);
      }),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),

    // ─── Bottom Navigation Bar ───────────────────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: OmniColors.bgSecondary,
      selectedItemColor: OmniColors.accent,
      unselectedItemColor: OmniColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // ─── Cards ──────────────────────────────────────────────────────────────
    cardTheme: const CardThemeData(
      color: OmniColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Color(0x12FFFFFF), width: 1),
      ),
    ),

    // ─── Inputs ─────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      fillColor: OmniColors.bgInput,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x12FFFFFF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x12FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: OmniColors.accent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: OmniColors.textMuted),
      labelStyle: const TextStyle(color: OmniColors.textSecondary),
    ),

    // ─── Buttons ────────────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: OmniColors.accent,
        foregroundColor: Colors.white,
        shadowColor: OmniColors.accentGlow,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.01,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: OmniColors.accent,
        side: const BorderSide(color: Color(0x40FFFFFF)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: OmniColors.accent,
      ),
    ),

    // ─── FAB ────────────────────────────────────────────────────────────────
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: OmniColors.accent,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),

    // ─── Dividers ───────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: Color(0x12FFFFFF),
      thickness: 1,
      space: 0,
    ),

    // ─── List tiles ─────────────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      iconColor: OmniColors.textSecondary,
      titleTextStyle: TextStyle(
        color: OmniColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: TextStyle(
        color: OmniColors.textSecondary,
        fontSize: 13,
      ),
    ),

    // ─── Chips ──────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: OmniColors.bgCard2,
      selectedColor: const Color(0x2600C8FF),
      labelStyle: const TextStyle(color: OmniColors.textPrimary, fontSize: 13),
      side: const BorderSide(color: Color(0x12FFFFFF)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // ─── Dialogs ────────────────────────────────────────────────────────────
    dialogTheme: const DialogThemeData(
      backgroundColor: OmniColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      titleTextStyle: TextStyle(
        color: OmniColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),

    // ─── Snackbar ───────────────────────────────────────────────────────────
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: OmniColors.bgCard,
      contentTextStyle: TextStyle(color: OmniColors.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // ─── Text ───────────────────────────────────────────────────────────────
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: OmniColors.textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: TextStyle(color: OmniColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: TextStyle(color: OmniColors.textPrimary, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: OmniColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: TextStyle(color: OmniColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
      titleSmall: TextStyle(color: OmniColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
      bodyLarge: TextStyle(color: OmniColors.textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: OmniColors.textSecondary, fontSize: 14),
      bodySmall: TextStyle(color: OmniColors.textSecondary, fontSize: 12),
      labelLarge: TextStyle(color: OmniColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: OmniColors.textMuted, fontSize: 11),
    ),

    // ─── Icon ───────────────────────────────────────────────────────────────
    iconTheme: const IconThemeData(color: OmniColors.textSecondary),

    // ─── Progress ───────────────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: OmniColors.accent,
    ),
  );
}
