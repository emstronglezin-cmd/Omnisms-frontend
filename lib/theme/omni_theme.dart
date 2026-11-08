import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'omni_design.dart';

/// ⚠️ Application mobile uniquement (APK / IPA). La PWA (`public/`) garde son
/// propre design et n'est pas concernée par ce fichier.

/// Thèmes Material 3 **complets** d'OmniSMS (clair + sombre).
///
/// Ils consomment exclusivement les jetons de `omni_design.dart`. Objectif :
/// qu'un écran qui n'utilise QUE les widgets standard (ListTile, Card,
/// TextField, ElevatedButton, Dialog…) soit déjà cohérent, moderne et lisible
/// dans les deux thèmes, sans la moindre couleur codée en dur.
abstract final class OmniTheme {
  /// Thème clair : fonds froids très légèrement bleutés, cartes blanches,
  /// accent cyan légèrement assombri pour garantir un contraste AA sur blanc.
  static ThemeData clair() => _construire(OmniCouleurs.clair());

  /// Thème sombre : fonds profonds (#08090F), surfaces à peine plus claires,
  /// accent cyan électrique, bordures discrètes plutôt que des ombres.
  static ThemeData sombre() => _construire(OmniCouleurs.sombre());

  static ThemeData _construire(OmniCouleurs c) {
    final scheme = ColorScheme(
      brightness: c.estSombre ? Brightness.dark : Brightness.light,
      primary: c.accent,
      onPrimary: c.surAccent,
      primaryContainer: c.accentDoux,
      onPrimaryContainer: c.texte,
      secondary: c.accentSecondaire,
      onSecondary: Colors.white,
      secondaryContainer: c.accentDoux,
      onSecondaryContainer: c.texte,
      tertiary: OmniPalette.info,
      onTertiary: Colors.white,
      surface: c.surface,
      onSurface: c.texte,
      surfaceContainerHighest: c.surfaceVariante,
      onSurfaceVariant: c.texteSecondaire,
      outline: c.contour,
      outlineVariant: c.contour.withValues(alpha: 0.6),
      error: OmniPalette.erreur,
      onError: Colors.white,
      errorContainer: OmniPalette.erreur.withValues(alpha: 0.12),
      onErrorContainer: OmniPalette.erreur,
      shadow: c.ombre,
      scrim: c.estSombre ? Colors.black87 : Colors.black38,
    );

    final texte = TextTheme(
      displayLarge: OmniTypo.display.copyWith(color: c.texte),
      displayMedium: OmniTypo.titre.copyWith(color: c.texte),
      headlineSmall: OmniTypo.titre.copyWith(color: c.texte),
      titleLarge: OmniTypo.sousTitre.copyWith(color: c.texte),
      titleMedium: OmniTypo.sousTitre.copyWith(color: c.texte),
      titleSmall: OmniTypo.corpsGras.copyWith(color: c.texte),
      bodyLarge: OmniTypo.corps.copyWith(color: c.texte),
      bodyMedium: OmniTypo.corps.copyWith(color: c.texte),
      bodySmall: OmniTypo.secondaire.copyWith(color: c.texteSecondaire),
      labelLarge: OmniTypo.corpsGras.copyWith(color: c.texte),
      labelMedium: OmniTypo.etiquette.copyWith(color: c.texteSecondaire),
      labelSmall: OmniTypo.micro.copyWith(color: c.texteEstompe),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.fond,
      canvasColor: c.fond,
      textTheme: texte,
      fontFamily: OmniTypo.corps.fontFamily,
      // Animation : Material 3 par défaut, durées resserrées par le design.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: c.fond,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.texte,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: c.overlay,
        titleTextStyle: OmniTypo.sousTitre.copyWith(color: c.texte),
        iconTheme: IconThemeData(color: c.texte, size: 22),
        actionsIconTheme: IconThemeData(color: c.texte, size: 22),
        toolbarHeight: 56,
      ),

      // ── Surfaces ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: OmniRayon.carte,
          side: BorderSide(color: c.contour),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: OmniRayon.carte),
        titleTextStyle: OmniTypo.sousTitre.copyWith(color: c.texte),
        contentTextStyle: OmniTypo.corps.copyWith(color: c.texteSecondaire),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.fondSecondaire,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.fondSecondaire,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: c.texteEstompe.withValues(alpha: 0.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(OmniRayon.xl)),
        ),
      ),

      // ── Listes ──────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: OmniEspace.l,
          vertical: OmniEspace.xs,
        ),
        minVerticalPadding: 10,
        iconColor: c.texteSecondaire,
        textColor: c.texte,
        titleTextStyle: OmniTypo.corpsGras.copyWith(color: c.texte),
        subtitleTextStyle: OmniTypo.secondaire.copyWith(
          color: c.texteSecondaire,
        ),
        shape: RoundedRectangleBorder(borderRadius: OmniRayon.champ),
      ),
      dividerTheme: DividerThemeData(
        color: c.contour,
        thickness: 1,
        space: 1,
      ),

      // ── Saisie ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceVariante,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: OmniEspace.l,
          vertical: 14,
        ),
        hintStyle: OmniTypo.corps.copyWith(color: c.texteEstompe),
        labelStyle: OmniTypo.corps.copyWith(color: c.texteSecondaire),
        prefixIconColor: c.texteSecondaire,
        suffixIconColor: c.texteSecondaire,
        border: _champ(c.contour),
        enabledBorder: _champ(c.contour),
        focusedBorder: _champ(c.accent, largeur: 1.6),
        errorBorder: _champ(OmniPalette.erreur),
        focusedErrorBorder: _champ(OmniPalette.erreur, largeur: 1.6),
        errorStyle: OmniTypo.secondaire.copyWith(color: OmniPalette.erreur),
      ),

      // ── Boutons ─────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.surAccent,
          disabledBackgroundColor: c.surfaceVariante,
          disabledForegroundColor: c.texteEstompe,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: OmniEspace.l),
          shape: RoundedRectangleBorder(borderRadius: OmniRayon.champ),
          textStyle: OmniTypo.corpsGras,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.surAccent,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: OmniRayon.champ),
          textStyle: OmniTypo.corpsGras,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.texte,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: c.contour),
          shape: RoundedRectangleBorder(borderRadius: OmniRayon.champ),
          textStyle: OmniTypo.corpsGras,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: OmniTypo.corpsGras,
          shape: RoundedRectangleBorder(borderRadius: OmniRayon.champ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.texte,
          iconSize: 22,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OmniRayon.s),
          ),
        ),
      ),

      // ── Navigation ──────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.fondSecondaire,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: c.accentDoux,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((etats) {
          final selectionne = etats.contains(WidgetState.selected);
          return IconThemeData(
            color: selectionne ? c.accent : c.texteEstompe,
            size: 23,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((etats) {
          final selectionne = etats.contains(WidgetState.selected);
          return OmniTypo.micro.copyWith(
            color: selectionne ? c.accent : c.texteEstompe,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.fondSecondaire,
        selectedItemColor: c.accent,
        unselectedItemColor: c.texteEstompe,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: OmniTypo.micro,
        unselectedLabelStyle: OmniTypo.micro,
      ),

      // ── Retours d'information ───────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.estSombre ? c.surfaceVariante : const Color(0xFF101828),
        contentTextStyle: OmniTypo.corps.copyWith(color: Colors.white),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: OmniRayon.champ),
        insetPadding: const EdgeInsets.all(OmniEspace.l),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceVariante,
        circularTrackColor: c.surfaceVariante,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (etats) => etats.contains(WidgetState.selected) ? Colors.white : c.texteEstompe,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (etats) => etats.contains(WidgetState.selected) ? c.accent : c.surfaceVariante,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceVariante,
        selectedColor: c.accentDoux,
        disabledColor: c.surfaceVariante,
        labelStyle: OmniTypo.etiquette.copyWith(color: c.texte),
        secondaryLabelStyle: OmniTypo.etiquette.copyWith(color: c.surAccent),
        side: BorderSide(color: c.contour),
        shape: RoundedRectangleBorder(borderRadius: OmniRayon.pill),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.surAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OmniRayon.m),
          ),
        extendedTextStyle: OmniTypo.corpsGras.copyWith(color: c.surAccent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.estSombre ? c.surfaceVariante : const Color(0xFF101828),
          borderRadius: BorderRadius.circular(OmniRayon.s),
        ),
        textStyle: OmniTypo.etiquette.copyWith(color: Colors.white),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static OutlineInputBorder _champ(Color couleur, {double largeur = 1}) =>
      OutlineInputBorder(
        borderRadius: OmniRayon.champ,
        borderSide: BorderSide(color: couleur, width: largeur),
      );
}
