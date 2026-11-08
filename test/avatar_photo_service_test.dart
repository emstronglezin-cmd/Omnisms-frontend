import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:omnisms/services/avatar_photo_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Portage FIDÈLE du filtre multer du backend (`services/uploadService.js`).
///
/// Le backend n'est pas modifié ; cette copie est volontairement verbatim :
///   if (!extOk && !mimeOk) → rejet 415 UNSUPPORTED_MEDIA_TYPE
/// Elle sert à démontrer que les fichiers produits par `AvatarPhotoService`
/// passent **le vrai** filtre serveur.
/// ─────────────────────────────────────────────────────────────────────────────
String? _filtreServeur(String nomFichier, String mimeType) {
  final ext = nomFichier.contains('.')
      ? '.${nomFichier.split('.').last.toLowerCase()}'
      : '';
  final mime = mimeType.toLowerCase();
  final extOk = kExtensionsImagesAcceptees.contains(ext);
  final mimeOk = kMimesImagesAcceptes.contains(mime);
  if (!extOk && !mimeOk) {
    return 'Format non autorisé: $mime ($ext)';
  }
  return null; // accepté
}

/// Génère une vraie image JPEG/PGN bruitée de [cote] px (incompressible).
Uint8List _imageBruit(int cote, {bool png = false}) {
  final rng = Random(42);
  final image = img.Image(width: cote, height: cote);
  for (var y = 0; y < cote; y++) {
    for (var x = 0; x < cote; x++) {
      image.setPixelRgba(
        x,
        y,
        rng.nextInt(256),
        rng.nextInt(256),
        rng.nextInt(256),
        255,
      );
    }
  }
  return Uint8List.fromList(png ? img.encodePng(image) : img.encodeJpg(image));
}

void main() {
  group('AvatarPhotoService — détection par magic bytes', () {
    test('reconnaît JPEG, PNG, GIF et WEBP', () {
      final png = _imageBruit(24, png: true);
      expect(AvatarPhotoService.detecterFormat(_imageBruit(24)),
          FormatImage.jpeg);
      expect(AvatarPhotoService.detecterFormat(png), FormatImage.png);

      final gif = Uint8List.fromList(<int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
      expect(AvatarPhotoService.detecterFormat(gif), FormatImage.gif);

      final webp = Uint8List.fromList(<int>[
        0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, //
        0x57, 0x45, 0x42, 0x50,
      ]);
      expect(AvatarPhotoService.detecterFormat(webp), FormatImage.webp);
    });

    test('un contenu HEIC est détecté comme inconnu', () {
      // « ftypheic » — signature ISO-BMFF des photos iPhone non converties.
      final heic = Uint8List.fromList(<int>[
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, //
        0x68, 0x65, 0x69, 0x63,
      ]);
      expect(AvatarPhotoService.detecterFormat(heic), FormatImage.inconnu);
    });

    test('un tampon trop court ne provoque aucune exception', () {
      expect(AvatarPhotoService.detecterFormat(Uint8List(0)),
          FormatImage.inconnu);
      expect(AvatarPhotoService.detecterFormat(Uint8List(3)),
          FormatImage.inconnu);
    });
  });

  group('AvatarPhotoService — acceptation par le serveur (filtre réel)', () {
    /// Les noms réellement renvoyés par les galeries Android/iOS, y compris
    /// ceux qui faisaient échouer l'upload avant le correctif.
    const nomsGalerie = <String>[
      'IMG_20240312_101500.jpg',
      'image_picker_1710234600', // sans extension (cache Android)
      'cf7e2f90-1a2b', // UUID temporaire
      'IMG_0042.HEIC',
      'photo de profil.png',
      '../../etc/passwd.jpg',
      '',
    ];

    for (final nom in nomsGalerie) {
      test('« ${nom.isEmpty ? '(vide)' : nom} » produit un fichier accepté',
          () {
        final resultat = AvatarPhotoService.preparer(
          octets: _imageBruit(64),
          nomSource: nom,
        );

        expect(resultat, isA<AvatarPhotoPreparee>());
        final photo = resultat as AvatarPhotoPreparee;

        // ── Le vrai filtre multer du backend doit accepter ──
        expect(
          _filtreServeur(photo.nomFichier, photo.mimeType),
          isNull,
          reason: 'le serveur doit accepter ${photo.nomFichier} '
              '(${photo.mimeType})',
        );

        // Cohérence : l'extension correspond au type MIME annoncé.
        expect(photo.nomFichier.toLowerCase().endsWith('.jpg'), isTrue);
        expect(photo.mimeType, 'image/jpeg');
        expect(photo.octets, isNotEmpty);
      });
    }

    test('le nom ne contient jamais de séparateur de chemin', () {
      final photo = AvatarPhotoService.preparer(
              octets: _imageBruit(32), nomSource: '../../etc/passwd.jpg')
          as AvatarPhotoPreparee;
      expect(photo.nomFichier.contains('/'), isFalse);
      expect(photo.nomFichier.contains('\\'), isFalse);
    });
  });

  group('AvatarPhotoService — compression réelle', () {
    test('une petite image valide n’est pas réencodée (qualité préservée)',
        () {
      final source = _imageBruit(48);
      final photo =
          AvatarPhotoService.preparer(octets: source, nomSource: 'a.jpg')
              as AvatarPhotoPreparee;

      expect(photo.recompressee, isFalse);
      expect(photo.octets, equals(source)); // octets strictement conservés
    });

    test('une image trop volumineuse est compressée sous la limite', () {
      // 900×900 de bruit : largement au-dessus des 400 Ko.
      final lourde = _imageBruit(900);
      expect(lourde.length, greaterThan(400 * 1024));

      final photo =
          AvatarPhotoService.preparer(octets: lourde, nomSource: 'grosse.jpg')
              as AvatarPhotoPreparee;

      expect(photo.recompressee, isTrue);
      expect(photo.octets.length, lessThanOrEqualTo(400 * 1024));
      expect(photo.octets.length, lessThan(lourde.length));
      // Le résultat reste un JPEG décodable.
      expect(img.decodeImage(photo.octets), isNotNull);
      // Et il reste accepté par le serveur.
      expect(_filtreServeur(photo.nomFichier, photo.mimeType), isNull);
    });

    test('le côté long est ramené à 512 px maximum', () {
      final photo = AvatarPhotoService.preparer(
              octets: _imageBruit(900), nomSource: 'grosse.jpg')
          as AvatarPhotoPreparee;
      final decode = img.decodeImage(photo.octets)!;
      expect(max(decode.width, decode.height), lessThanOrEqualTo(512));
    });
  });

  group('AvatarPhotoService — pas d’image fictive', () {
    test('un contenu illisible renvoie une erreur explicite', () {
      final poubelle = Uint8List.fromList(List<int>.generate(
        64,
        (i) => (i * 7) % 251,
      ));
      final resultat =
          AvatarPhotoService.preparer(octets: poubelle, nomSource: 'x.jpg');

      expect(resultat, isA<AvatarPhotoErreur>());
      final erreur = resultat as AvatarPhotoErreur;
      expect(erreur.message, contains('non pris en charge'));
      // Aucune image de substitution n'est fabriquée.
      expect(erreur.message, isNot(contains('avatar')));
    });

    test('une image vide est refusée', () {
      expect(
        AvatarPhotoService.preparer(octets: Uint8List(0)),
        isA<AvatarPhotoErreur>(),
      );
    });
  });
}
