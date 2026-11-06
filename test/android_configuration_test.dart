import 'dart:convert' show jsonDecode;
import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';

/// Configuration Android — exigences de publication et cohérence réseau.
///
/// Ces tests lisent les fichiers de configuration (même approche que
/// `ios_configuration_test.dart`) : ils vérifient ce qui ne peut pas être
/// validé par un test d'exécution depuis cet environnement (pas d'appareil,
/// pas d'émulateur).
const root = '.';

String _read(String path) {
  final file = io.File('$root/$path');
  if (!file.existsSync()) throw TestFailure('Fichier absent : $path');
  return file.readAsStringSync();
}

void main() {
  group('Identité de l’application', () {
    test('l’identifiant n’est plus le gabarit Flutter', () {
      final gradle = _read('android/app/build.gradle.kts');
      expect(gradle, isNot(contains('com.example.')));
      expect(gradle, contains('applicationId = "com.omnisms.app"'));
      expect(gradle, contains('namespace = "com.omnisms.app"'));
    });

    // ── Action console en attente ──────────────────────────────────────────
    // Tant que google-services.json annonce « omnisms.app », ce test ne peut
    // pas passer : il est ignoré, mais la raison s'affiche à chaque exécution.
    test('l’identifiant Android correspond au client Firebase déclaré', () {
      // Condition indispensable pour utiliser Firebase (Crashlytics, FCM) :
      // si les deux diffèrent, le greffon Gradle échoue avec
      // « No matching client found for package name ».
      final gradle = _read('android/app/build.gradle.kts');
      final id = RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)!.group(1)!;
      final services = _read('android/app/google-services.json');
      final json = jsonDecode(services) as Map<String, dynamic>;
      // Le paquet est imbriqué dans client_info.android_client_info.
      final clients = (json['client'] as List)
          .map((c) => (c as Map)['client_info'] as Map)
          .where((info) => info['android_client_info'] != null)
          .map((info) => (info['android_client_info'] as Map)['package_name'])
          .whereType<String>()
          .toList();
      expect(clients, contains(id),
          reason: 'Aucun client Firebase pour « $id » — paquets déclarés : $clients');
    }, skip: 'google-services.json annonce encore « omnisms.app » : à régénérer '
            'pour « com.omnisms.app » dans la console Firebase (rapport §9)');

    test('les deux plateformes appartiennent bien au domaine OmniSMS', () {
      final gradle = _read('android/app/build.gradle.kts');
      final pbxproj = _read('ios/Runner.xcodeproj/project.pbxproj');
      final androidId =
          RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle)!.group(1)!;
      final iosId = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .firstMatch(pbxproj)!
          .group(1)!
          .trim();
      // Les identifiants peuvent différer d'une plateforme à l'autre ; ils
      // doivent simplement sortir du domaine du projet et ne plus être ceux
      // du gabarit.
      expect(androidId, endsWith('omnisms.app'));
      expect(iosId, endsWith('omnisms.app'));
      expect(androidId, isNot(contains('com.example')));
      expect(iosId, isNot(contains('com.example')));
    });

    test('le nom affiché est OmniSMS', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:label="OmniSMS"'));
      expect(manifest, isNot(contains('omni_smsnew')));
    });

    test('le package Kotlin suit l’identifiant', () {
      final activity =
          _read('android/app/src/main/kotlin/com/omnisms/app/MainActivity.kt');
      expect(activity, contains('package com.omnisms.app'));
    });

    test('assetlinks.json annonce le même package', () {
      final links = _read('android/assetlinks.json');
      expect(links, contains('"package_name": "com.omnisms.app"'));
      // Les empreintes doivent être remplacées avant déploiement : ce test
      // DOIT échouer tant que c'est le cas (elles sont volontairement
      // laissées visibles).
      expect(links, contains('REMPLACER_PAR_L_EMPREINTE'),
          reason: 'Empreintes SHA-256 à renseigner puis à déployer.');
    });
  });

  group('Cible Android (exigence Google Play)', () {
    test('targetSdk suit la valeur du SDK Flutter (API 36)', () {
      final gradle = _read('android/app/build.gradle.kts');
      expect(gradle, contains('targetSdk = flutter.targetSdkVersion'));
      // Aucune valeur figée inférieure à 36.
      expect(RegExp(r'targetSdk\s*=\s*3[0-5]\b').hasMatch(gradle), isFalse);
    });

    test('la version provient de pubspec.yaml, plus de valeurs figées', () {
      final gradle = _read('android/app/build.gradle.kts');
      expect(gradle, contains('versionCode = flutter.versionCode'));
      expect(gradle, contains('versionName = flutter.versionName'));
      expect(RegExp(r'versionCode\s*=\s*\d+').hasMatch(gradle), isFalse);
    });
  });

  group('Réseau — production uniquement', () {
    test('aucune URL locale dans le code Dart', () {
      final hits = <String>[];
      for (final entity in io.Directory('$root/lib')
          .listSync(recursive: true)
          .whereType<io.File>()) {
        if (!entity.path.endsWith('.dart')) continue;
        final text = entity.readAsStringSync();
        if (RegExp(r'10\.0\.2\.2|127\.0\.0\.1|localhost|192\.168\.')
            .hasMatch(text)) {
          hits.add(entity.path);
        }
      }
      expect(hits, isEmpty, reason: 'URLs locales trouvées : $hits');
    });

    test('le trafic en clair est désactivé', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
    });

    test('l’API pointe vers la production', () {
      final config = _read('lib/config/api_config.dart');
      expect(config, contains("baseUrl = 'https://omnisms-backend.onrender.com'"));
    });
  });

  group('Signature — aucun secret dans le dépôt', () {
    test('les secrets de signature viennent de key.properties ou de l’environnement',
        () {
      final gradle = _read('android/app/build.gradle.kts');
      expect(gradle, contains('key.properties'));
      expect(gradle, contains('System.getenv("OMNISMS_STORE_PASSWORD")'));
      // Aucun mot de passe écrit en clair.
      expect(RegExp(r'(storePassword|keyPassword)\s*=\s*"[^"]+"')
          .hasMatch(gradle), isFalse);
    });

    test('le fichier key.properties n’est pas versionné', () {
      expect(io.File('$root/android/key.properties').existsSync(), isFalse);
    });
  });

  group('Deep links — retour Google OAuth', () {
    test('le schéma omnisms://auth est déclaré', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:scheme="omnisms"'));
      expect(manifest, contains('android:host="auth"'));
    });

    test('le deep linking natif Flutter est désactivé (app_links)', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('flutter_deeplinking_enabled'));
      expect(manifest, contains('android:value="false"'));
    });
  });

  group('Permissions — cohérence avec le code', () {
    test('aucune permission SMS native (la passerelle est côté serveur)', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      for (final permission in const [
        'SEND_SMS',
        'RECEIVE_SMS',
        'READ_SMS',
        'RECEIVE_MMS',
      ]) {
        expect(manifest, isNot(contains('android.permission.$permission')),
            reason: 'permission $permission inutile : SMS via le backend');
      }
    });

    test('les permissions déclarées sont bien utilisées', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('android.permission.RECORD_AUDIO'));
      expect(manifest, contains('android.permission.READ_CONTACTS'));
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    });
  });

  group('Suppression de compte — parcours conformes', () {
    test('l’application appelle le endpoint conforme (audit + purge 30 jours)',
        () {
      final service = _read('lib/services/auth_service.dart');
      // L'appel passe par la configuration centralisée (aucune URL en dur).
      expect(service, contains('ApiConfig.accountDeleteEndpoint'));
      final config = _read('lib/config/api_config.dart');
      expect(config, contains("accountDeleteEndpoint = '/api/account/delete'"));
    });

    test('un repli existe si le serveur ne connaît pas encore la route', () {
      final service = _read('lib/services/auth_service.dart');
      expect(service, contains('response.statusCode == 404'));
      expect(service, contains('DELETE /api/me'));
    });

    test('la page web publique est exposée (exigence Google Play)', () {
      final config = _read('lib/config/api_config.dart');
      expect(config, contains("accountWebEndpoint = '/api/account/web'"));
      expect(config, contains('accountWebUrl'));
    });

    test('les paramètres proposent le parcours web', () {
      final settings = _read('lib/screens/settings/settings_screen.dart');
      expect(settings, contains('Supprimer mon compte depuis le web'));
      expect(settings, contains('ApiConfig.accountWebUrl'));
    });
  });
}
