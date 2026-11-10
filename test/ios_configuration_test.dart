// ─────────────────────────────────────────────────────────────────────────
// Tests de la configuration iOS d'OmniSMS.
//
// L'environnement de développement est Linux : ni Xcode, ni CocoaPods, ni
// simulateur ne sont disponibles. Ces tests couvrent donc ce qui est
// vérifiable sans macOS — c'est-à-dire l'essentiel des erreurs qui font
// échouer un build ou une soumission App Store :
//   • présence et validité des fichiers de configuration ;
//   • clés de permissions et d'usage (une clé manquante = crash à l'usage) ;
//   • identifiant de bundle (un `com.example.*` est refusé) ;
//   • cible iOS cohérente avec les exigences des plugins ;
//   • manifeste de confidentialité Apple ;
//   • comportement propre à iOS côté Dart (permission de notification).
//
// Ils complètent — sans les remplacer — les vérifications à faire sur Mac :
// `pod install`, `flutter build ios`, archive et `flutter build ipa`.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnisms/config/api_config.dart';
import 'package:omnisms/services/notification_service.dart';

const String _ios = 'ios';
const String _infoPlist = '$_ios/Runner/Info.plist';
const String _pbxproj = '$_ios/Runner.xcodeproj/project.pbxproj';
const String _privacy = '$_ios/Runner/PrivacyInfo.xcprivacy';

String _read(String path) => File(path).readAsStringSync();

/// Nombre d'occurrences de `motif` dans `contenu` (recherche littérale).
int _count(String contenu, String motif) {
  var total = 0;
  var index = contenu.indexOf(motif);
  while (index != -1) {
    total++;
    index = contenu.indexOf(motif, index + motif.length);
  }
  return total;
}


/// Dimensions d'un PNG lues dans son en-tête (IHDR), sans décodeur d'image.
List<int> _taillePng(File fichier) {
  final octets = fichier.readAsBytesSync();
  expect(octets.length, greaterThan(24));
  int lire32(int debut) =>
      (octets[debut] << 24) |
      (octets[debut + 1] << 16) |
      (octets[debut + 2] << 8) |
      octets[debut + 3];
  // Signature PNG : 8 octets, puis longueur + « IHDR » (8 octets).
  return <int>[lire32(16), lire32(20)];
}

void main() {
  group('Fichiers de configuration iOS', () {
    test('le Podfile existe et fixe la cible iOS', () {
      final podfile = File('$_ios/Podfile');
      expect(podfile.existsSync(), isTrue,
          reason: 'Sans Podfile, `pod install` est impossible : '
              'aucun build iOS ne peut aboutir.');

      final contenu = podfile.readAsStringSync();
      // 15.0 est imposé par le moteur : Flutter 3.47.7 génère, pendant
      // `pod install`, un podspec « Flutter » qui déclare
      // s.ios.deployment_target = '15.0'. Une cible inférieure fait échouer
      // la résolution CocoaPods.
      expect(contenu.contains("platform :ios, '15.0'"), isTrue,
          reason: 'La cible minimale est imposée par le moteur Flutter 3.47.7 '
              '(podspec du moteur : s.ios.deployment_target = 15.0). Une '
              'valeur inférieure fait échouer pod install.');
      expect(contenu.contains("target 'Runner' do"), isTrue);
      expect(contenu.contains('flutter_install_all_ios_pods'), isTrue,
          reason: 'Le Podfile doit installer les pods des plugins Flutter.');
    });

    test('le projet Xcode et l\'espace de travail existent', () {
      expect(File(_pbxproj).existsSync(), isTrue);
      expect(
        File('$_ios/Runner.xcworkspace/contents.xcworkspacedata').existsSync(),
        isTrue,
      );
    });

    test('les ressources graphiques de lancement et l\'icône sont présentes',
        () {
      const icones = '$_ios/Runner/Assets.xcassets/AppIcon.appiconset';
      expect(File('$icones/Icon-App-1024x1024@1x.png').existsSync(), isTrue,
          reason: 'App Store Connect exige une icône 1024×1024 sans canal '
              'alpha et sans arrondi.');

      // Les images de lancement du gabarit Flutter sont des carrés 1×1 :
      // on vérifie qu'elles ont bien été remplacées par le logo OmniSMS.
      for (final couple in <MapEntry<String, int>>[
        const MapEntry('LaunchImage.png', 180),
        const MapEntry('LaunchImage@2x.png', 360),
        const MapEntry('LaunchImage@3x.png', 540),
      ]) {
        final fichier = File(
          '$_ios/Runner/Assets.xcassets/LaunchImage.imageset/${couple.key}',
        );
        expect(fichier.existsSync(), isTrue);
        expect(_taillePng(fichier), <int>[couple.value, couple.value],
            reason: '${couple.key} doit mesurer '
                '${couple.value}×${couple.value} px.');
      }
    });
  });

  group('Info.plist — permissions et déclarations', () {
    late String plist;

    setUp(() => plist = _read(_infoPlist));

    test('le nom affiché est OmniSMS', () {
      expect(plist.contains('<string>OmniSMS</string>'), isTrue);
      expect(plist.contains('Omni Smsnew'), isFalse,
          reason: 'Le nom issu de `flutter create` ne doit pas être publié.');
    });

    test('les trois permissions réellement utilisées sont déclarées', () {
      // Photothèque : image_picker (photo de profil). Sans cette clé,
      // l'application se ferme dès la sélection d'une image.
      expect(plist.contains('NSPhotoLibraryUsageDescription'), isTrue);
      // Micro : messages vocaux et transcription.
      expect(plist.contains('NSMicrophoneUsageDescription'), isTrue);
      // Contacts : import du carnet d'adresses.
      expect(plist.contains('NSContactsUsageDescription'), isTrue);
    });

    test('aucune permission non utilisée n\'est déclarée', () {
      // L'application n'ouvre ni l'appareil photo, ni la localisation,
      // ni le suivi publicitaire : ces clés ne doivent pas apparaître.
      for (final cle in <String>[
        'NSCameraUsageDescription',
        'NSLocationWhenInUseUsageDescription',
        'NSLocationAlwaysAndWhenInUseUsageDescription',
        'NSUserTrackingUsageDescription',
        'NSAppleMusicUsageDescription',
        'NSCalendarsUsageDescription',
      ]) {
        expect(plist.contains(cle), isFalse,
            reason: 'Clé déclarée sans fonctionnalité correspondante : $cle');
      }
    });

    test('le chiffrement est déclaré pour App Store Connect', () {
      expect(plist.contains('ITSAppUsesNonExemptEncryption'), isTrue,
          reason: 'Sans cette clé, App Store Connect bloque le dépôt du '
              'build en demandant la déclaration de chiffrement.');
    });

    test('le schéma d\'URL du retour OAuth Google est déclaré', () {
      expect(plist.contains('CFBundleURLTypes'), isTrue);
      expect(plist.contains('<string>omnisms</string>'), isTrue,
          reason: 'Le retour Google arrive sur omnisms://auth/google/callback.');
    });

    test('l\'orientation est verrouillée en portrait, comme dans main.dart', () {
      final bloc = plist.substring(plist.indexOf('UISupportedInterfaceOrientations'));
      final orientations = bloc.substring(0, bloc.indexOf('</array>'));
      expect(orientations.contains('Landscape'), isFalse,
          reason: 'main.dart verrouille le portrait : l\'Info.plist doit '
              'suivre, sinon l\'interface se casse en paysage.');
    });
  });

  group('Projet Xcode (project.pbxproj)', () {
    late String projet;

    setUp(() => projet = _read(_pbxproj));

    test('l\'identifiant de bundle n\'est plus un placeholder de gabarit', () {
      expect(projet.contains('PRODUCT_BUNDLE_IDENTIFIER = com.omnisms.app;'),
          isTrue);
      expect(projet.contains('com.example.'), isFalse,
          reason: 'Le préfixe com.example.* est réservé : App Store Connect '
              'refuse de l\'enregistrer.');
    });

    test('la cible est l\'iPhone (application de téléphonie)', () {
      // `pod install` réécrit project.pbxproj avant que les tests ne tournent :
      // CocoaPods re-sérialise le fichier et peut retirer les guillemets
      // (TARGETED_DEVICE_FAMILY = 1 au lieu de = "1"). On compare donc la
      // valeur, pas sa mise en forme.
      final familles = RegExp(r'TARGETED_DEVICE_FAMILY\s*=\s*"?([^;"]+)"?\s*;')
          .allMatches(projet)
          .map((m) => m.group(1)!.trim())
          .toSet();
      expect(familles, equals({'1'}),
          reason: 'Familles d\'appareils déclarées : $familles. Seul '
              'l\'iPhone doit être visé : déclarer l\'iPad (\'1,2\') expose '
              'l\'application à une revue sur tablette.');
    });

    test('la version suit pubspec.yaml', () {
      // La version attendue est lue dans pubspec.yaml, jamais recopiée :
      // c'est ce qui évite qu'un test fige « 2.5.0 » alors que
      // l'application est passée en 3.0.0.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
              multiLine: true)
          .firstMatch(pubspec)
          ?.group(1);
      expect(version, isNotNull,
          reason: 'Version introuvable dans pubspec.yaml.');

      expect(
        _count(projet, 'MARKETING_VERSION = $version;'),
        3,
        reason: 'Les trois configurations (Debug, Release, Profile) doivent '
            'porter la version $version, celle de pubspec.yaml.',
      );
    });

    test('le manifeste de confidentialité est bien embarqué dans la ressource',
        () {
      // Le fichier doit être déclaré (référence), placé dans le groupe Runner
      // et ajouté à la phase « Copy Bundle Resources ». Un oubli = manifeste
      // absent du bundle Apple.
      expect(projet.contains('path = PrivacyInfo.xcprivacy;'), isTrue);
      expect(
        projet.contains('3B80C1A42F6A00A1000000A1 /* PrivacyInfo.xcprivacy */,'),
        isTrue,
      );
      // Deux occurrences : la déclaration du fichier de build et son entrée
      // dans la phase de ressources.
      expect(_count(projet, 'PrivacyInfo.xcprivacy in Resources'), 2);
    });

    test('aucune équipe de signature ni identifiant Apple n\'est figé', () {
      // L'équipe est renseignée dans Xcode, sur le Mac de build : la figer
      // ici casserait la compilation pour tout autre développeur.
      expect(projet.contains('DEVELOPMENT_TEAM'), isFalse);
      expect(projet.contains('CODE_SIGN_STYLE = Automatic;'), isTrue);
    });
  });

  group('Manifeste de confidentialité Apple', () {
    test('le fichier existe et est un plist valide', () {
      final contenu = _read(_privacy);
      expect(contenu.contains('NSPrivacyTracking'), isTrue);
      expect(contenu.contains('NSPrivacyCollectedDataTypes'), isTrue);
      expect(contenu.contains('NSPrivacyAccessedAPITypes'), isTrue);
    });

    test('aucun suivi publicitaire n\'est déclaré', () {
      final contenu = _read(_privacy);
      // <key>NSPrivacyTracking</key><false/> — l'application n'utilise ni
      // IDFA ni domaine de suivi.
      expect(
        contenu.contains('<key>NSPrivacyTracking</key>\n\t<false/>'),
        isTrue,
        reason: 'Le SDK Start.io est lié mais jamais initialisé : aucun suivi '
            'n\'a lieu. Toute déclaration contraire serait inexacte.',
      );
      expect(contenu.contains('NSPrivacyTrackingDomains'), isTrue);
    });

    test('les catégories de données collectées sont déclarées', () {
      final contenu = _read(_privacy);
      for (final type in <String>[
        'NSPrivacyCollectedDataTypePhoneNumber',
        'NSPrivacyCollectedDataTypeEmailAddress',
        'NSPrivacyCollectedDataTypeContacts',
        'NSPrivacyCollectedDataTypeOtherUserContent',
        'NSPrivacyCollectedDataTypePurchaseHistory',
      ]) {
        expect(contenu.contains(type), isTrue,
            reason: 'Donnée effectivement collectée mais non déclarée : $type');
      }
    });
  });

  group('Comportement Dart propre à iOS', () {
    test('la permission de notification n\'est jamais demandée au démarrage '
        'sur iOS', () {
      // iOS : l'alerte système n'est présentée qu'une seule fois. La dépenser
      // au premier lancement est contraire aux attentes d'Apple ; elle est
      // réservée à « Paramètres → Notifications ».
      expect(
        shouldRequestNotificationPermissionAtStartup(
            isAndroid: false, isWeb: false),
        isFalse,
      );
      // Android 13+ : dialogue ré-affichable, sans blocage de l'application.
      expect(
        shouldRequestNotificationPermissionAtStartup(
            isAndroid: true, isWeb: false),
        isTrue,
      );
      // Web/PWA : un geste de l'utilisateur est requis par le navigateur.
      expect(
        shouldRequestNotificationPermissionAtStartup(
            isAndroid: false, isWeb: true),
        isFalse,
      );
    });

    test('la plateforme courante est cohérente avec kIsWeb', () {
      // Sécurité : si l'application tournait sur le Web, il ne faudrait en
      // aucun cas déclencher une demande automatique.
      if (kIsWeb) {
        expect(
          shouldRequestNotificationPermissionAtStartup(
              isAndroid: true, isWeb: true),
          isFalse,
        );
      }
    });
  });

  group('Politique de confidentialité (exigence App Store)', () {
    test('aucune URL de politique de confidentialite n est inventee', () {
      // Une adresse vide ou en HTTPS, jamais une URL approximative : une
      // politique inexistante serait un motif de rejet (règle 5.1.1).
      expect(ApiConfig.privacyPolicyUrl, anyOf(isEmpty, startsWith('https://')));
    });

    test("l'entree des parametres n'apparait que si elle est configuree", () {
      // Rien n'est affiché tant que l'URL n'est pas fournie : aucune fonction
      // annoncée ne doit être cassée.
      final parametres = _read('lib/screens/settings/settings_screen.dart');
      expect(parametres.contains('if (ApiConfig.hasPrivacyPolicy)'), isTrue);
      expect(
        ApiConfig.hasPrivacyPolicy,
        isFalse,
        reason: 'À renseigner avant soumission : ApiConfig.privacyPolicyUrl.',
      );
    });
  });

  group('Publicités — aucune initialisation hors Android', () {
    test('le service publicitaire est limité à Android dans le code source',
        () {
      final source = _read('lib/services/ads_service.dart');
      expect(source.contains('!kIsWeb && Platform.isAndroid'), isTrue,
          reason: 'Sur iOS, le SDK Start.io ne doit jamais être initialisé : '
              'cette garde protège le binaire de tout appel publicitaire.');
    });
  });
}
