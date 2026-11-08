import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnisms/theme/omni_design.dart';
import 'package:omnisms/theme/omni_theme.dart';

/// Luminance relative (WCAG 2.1) — sert au calcul du ratio de contraste.
double _luminance(Color couleur) {
  // Depuis Flutter 3.27, `Color.r/g/b` sont des doubles 0–1 (et non 0–255).
  double canal(double valeur) {
    final v = valeur.clamp(0.0, 1.0);
    // Formule WCAG 2.1 : linéarisation avec un exposant de 2.4.
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }
  return 0.2126 * canal(couleur.r) +
      0.7152 * canal(couleur.g) +
      0.0722 * canal(couleur.b);
}

/// Ratio de contraste WCAG entre deux couleurs opaques.
double _contraste(Color premier, Color second) {
  final a = _luminance(premier);
  final b = _luminance(second);
  final clair = a > b ? a : b;
  final sombre = a > b ? b : a;
  return (clair + 0.05) / (sombre + 0.05);
}

/// Ratio attendu selon la taille du texte :
///  - texte courant  : 4.5:1
///  - grand texte / éléments graphiques (badges, icônes) : 3:1
void _attendLisible(String libelle, Color texte, Color fond,
    {double minimum = 4.5}) {
  final ratio = _contraste(texte, fond);
  expect(
    ratio >= minimum,
    isTrue,
    reason: '$libelle : contraste $ratio (minimum $minimum) — '
        'texte $texte sur fond $fond',
  );
}

void main() {
  group('Design system — thèmes', () {
    test('clair et sombre sont construits sans erreur', () {
      final clair = OmniTheme.clair();
      final sombre = OmniTheme.sombre();

      expect(clair.brightness, Brightness.light);
      expect(sombre.brightness, Brightness.dark);
      expect(clair.useMaterial3, isTrue);
      expect(sombre.useMaterial3, isTrue);
    });

    test('les deux thèmes définissent les composants refondus', () {
      for (final theme in <ThemeData>[OmniTheme.clair(), OmniTheme.sombre()]) {
        expect(theme.appBarTheme.elevation, 0);
        expect(theme.cardTheme.elevation, 0);
        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(theme.navigationBarTheme.backgroundColor, isNotNull);
        expect(theme.listTileTheme.titleTextStyle, isNotNull);
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
        expect(theme.bottomSheetTheme.showDragHandle, isTrue);
      }
    });

    test('OmniCouleurs suit la luminosité du thème', () async {
      // Résolution via BuildContext : clair d'un côté, sombre de l'autre.
      final clair = OmniCouleurs.clair();
      final sombre = OmniCouleurs.sombre();

      expect(clair.estSombre, isFalse);
      expect(sombre.estSombre, isTrue);
      expect(clair.fond, isNot(equals(sombre.fond)));
      expect(clair.texte, isNot(equals(sombre.texte)));
    });
  });

  group('Design system — lisibilité (WCAG)', () {
    test('thème sombre : le texte reste lisible sur chaque surface', () {
      final c = OmniCouleurs.sombre();

      _attendLisible('texte principal / fond', c.texte, c.fond);
      _attendLisible('texte principal / surface', c.texte, c.surface);
      _attendLisible('texte principal / surface variante', c.texte,
          c.surfaceVariante);
      _attendLisible(
          'texte secondaire / fond', c.texteSecondaire, c.fond, minimum: 4.5);
      _attendLisible(
          'texte de bulle sortante / bulle', c.bulleSortanteTexte,
          c.bulleSortante);
      _attendLisible(
          'texte de bulle entrante / bulle', c.bulleEntranteTexte,
          c.bulleEntrante);
      _attendLisible(
          'accent / fond (liens, icônes actives)', c.accent, c.fond,
          minimum: 3);
    });

    test('thème clair : le texte reste lisible sur chaque surface', () {
      final c = OmniCouleurs.clair();

      _attendLisible('texte principal / fond', c.texte, c.fond);
      _attendLisible('texte principal / surface', c.texte, c.surface);
      _attendLisible('texte principal / surface variante', c.texte,
          c.surfaceVariante);
      _attendLisible(
          'texte secondaire / fond', c.texteSecondaire, c.fond, minimum: 4.5);
      _attendLisible(
          'texte de bulle sortante / bulle', c.bulleSortanteTexte,
          c.bulleSortante);
      _attendLisible(
          'texte de bulle entrante / bulle', c.bulleEntranteTexte,
          c.bulleEntrante);
      _attendLisible(
          'accent / fond (liens, icônes actives)', c.accent, c.fond,
          minimum: 3);
    });

    test('les couleurs sémantiques sont distinctes de l’accent', () {
      // Un succès, une erreur ou un avertissement ne doivent pas être
      // confondus avec la couleur de marque.
      final accents = <Color>{
        OmniPalette.cyan,
        OmniPalette.bleu,
      };
      for (final couleur in <Color>[
        OmniPalette.succes,
        OmniPalette.erreur,
        OmniPalette.avertissement,
      ]) {
        expect(accents.contains(couleur), isFalse);
      }
    });
  });

  group('Design system — jetons', () {
    test('les rayons de bulles sont asymétriques (signature Omni)', () {
      // Bas-droit resserré sur une bulle sortante, bas-gauche sur une entrante
      // : c'est ce qui distingue visuellement les deux interlocuteurs.
      expect(
        OmniRayon.bulleSortante.bottomRight.x,
        lessThan(OmniRayon.bulleSortante.bottomLeft.x),
      );
      expect(
        OmniRayon.bulleEntrante.bottomLeft.x,
        lessThan(OmniRayon.bulleEntrante.bottomRight.x),
      );
    });

    test('les durées d’animation restent discrètes (< 400 ms)', () {
      for (final duree in <Duration>[
        OmniMouvement.rapide,
        OmniMouvement.normal,
        OmniMouvement.lent,
      ]) {
        expect(duree.inMilliseconds, lessThan(400));
      }
    });
  });
}
