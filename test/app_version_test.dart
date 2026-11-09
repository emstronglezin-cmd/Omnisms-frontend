import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/utils/app_version.dart';

/// Le numéro de version existe à deux endroits :
/// * `pubspec.yaml`, que Flutter utilise pour Android et iOS ;
/// * `lib/utils/app_version.dart`, que l'interface affiche.
///
/// Sans contrôle automatisé, les deux finissent toujours par diverger — et
/// l'application affiche alors une version qui n'est pas celle du binaire.
/// Ces tests sont la garantie de cohérence.
void main() {
  String pubspecVersion() {
    final fichier = File('pubspec.yaml');
    expect(fichier.existsSync(), isTrue,
        reason: 'pubspec.yaml doit être lisible depuis la racine du paquet.');

    for (final ligne in fichier.readAsLinesSync()) {
      final correspondance =
          RegExp(r'^version:\s*(\S+)\s*$').firstMatch(ligne);
      if (correspondance != null) return correspondance.group(1)!;
    }
    fail('Aucune ligne « version: » trouvée dans pubspec.yaml.');
  }

  group('Version de l’application', () {
    test('la version du code correspond exactement à celle du pubspec', () {
      expect(AppVersion.pubspec, pubspecVersion(),
          reason: 'pubspec.yaml et lib/utils/app_version.dart divergent.');
    });

    test('le numéro affiché est bien la V3', () {
      expect(AppVersion.version, '3.0.0');
      expect(AppVersion.nom, 'OmniSMS V3');
    });

    test('le numéro de build est monotone et supérieur à celui de la V2.5',
        () {
      // V2.5 était en build 1. Un build strictement supérieur est exigé par
      // Google Play et par l'App Store pour accepter une mise à jour.
      expect(AppVersion.build, greaterThan(1));
    });

    test('les formats affichables sont complets', () {
      expect(AppVersion.complete, '3.0.0 (3)');
      expect(AppVersion.courte, 'V3.0.0');
    });
  });
}
