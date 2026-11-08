import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Formats *réellement* acceptés par le backend.
///
/// Copiés volontairement tels quels depuis
/// `services/uploadService.js` (`ALLOWED.images`), backend non modifié.
/// Toute valeur envoyée en dehors de ces listes est rejetée en 415
/// (`UNSUPPORTED_MEDIA_TYPE`) par le filtre multer.
const List<String> kMimesImagesAcceptes = <String>[
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/gif',
  'image/webp',
];

const List<String> kExtensionsImagesAcceptees = <String>[
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
];

/// Taille maximale acceptée par la route `POST /api/me/avatar`.
///
/// Le serveur refuse au-delà de `MAX_AVATAR_B64 = 800 * 1024` **en base64**,
/// soit ~600 Ko de fichier. On vise 400 Ko pour garder de la marge : la marge
/// absorbe le surcoût base64 (+33 %) et les en-têtes multipart.
const int kTailleMaxAvatarOctets = 400 * 1024;

/// Côté long maximal après réencodage (les avatars sont affichés en 56–120 px).
const int kCoteMaxAvatar = 512;

/// Format d'image détecté par **magic bytes** (jamais par le nom de fichier).
enum FormatImage { jpeg, png, gif, webp, inconnu }

/// Résultat de la préparation d'une photo de profil.
sealed class AvatarPhotoResultat {
  const AvatarPhotoResultat();
}

/// Photo prête à être envoyée : octets, nom de fichier et type MIME cohérents.
class AvatarPhotoPreparee extends AvatarPhotoResultat {
  const AvatarPhotoPreparee({
    required this.octets,
    required this.nomFichier,
    required this.mimeType,
    required this.recompressee,
  });

  final Uint8List octets;
  final String nomFichier;
  final String mimeType;

  /// Vrai si l'image a dû être réencodée (format non géré ou fichier trop
  /// volumineux). Utile pour les tests et pour les journaux, jamais affiché
  /// tel quel à l'utilisateur.
  final bool recompressee;
}

/// Échec explicite : aucun envoi ne doit avoir lieu.
class AvatarPhotoErreur extends AvatarPhotoResultat {
  const AvatarPhotoErreur(this.message);
  final String message;
}

/// Prépare une photo de profil pour `POST /api/me/avatar`.
///
/// Pourquoi ce service existe — diagnostic réel (nov. 2026) :
///   1. `image_picker` renvoie parfois un nom de fichier **sans extension**
///      (`image_picker_1710234600`, UUID de cache…) ou en `.heic` ;
///   2. `http.MultipartFile.fromBytes` posait `application/octet-stream` ;
///   3. le filtre multer du backend (`mimeFilter`) accepte si
///      **extension OU type MIME** correspond — donc 1 + 2 ⇒ rejet 415
///      systématique, et la photo n'était jamais enregistrée.
///
/// Ce service garantit qu'un fichier accepté par le serveur est produit, en
/// partant du **contenu réel** (magic bytes), jamais du nom. Aucune image
/// fictive n'est fabriquée : si le format est illisible, on renvoie une erreur.
class AvatarPhotoService {
  const AvatarPhotoService._();

  /// Détecte le format réel à partir des premiers octets.
  static FormatImage detecterFormat(Uint8List octets) {
    // Chaque signature est testée avec la longueur minimale qui la contient :
    // un GIF ne nécessite que 4 octets, un WEBP en demande 12.
    if (octets.length >= 3 &&
        octets[0] == 0xFF &&
        octets[1] == 0xD8 &&
        octets[2] == 0xFF) {
      return FormatImage.jpeg;
    }
    // PNG : 89 50 4E 47 0D 0A 1A 0A
    if (octets.length >= 4 &&
        octets[0] == 0x89 &&
        octets[1] == 0x50 &&
        octets[2] == 0x4E &&
        octets[3] == 0x47) {
      return FormatImage.png;
    }
    // GIF : "GIF8"
    if (octets.length >= 4 &&
        octets[0] == 0x47 &&
        octets[1] == 0x49 &&
        octets[2] == 0x46 &&
        octets[3] == 0x38) {
      return FormatImage.gif;
    }
    // WEBP : "RIFF" …. "WEBP"
    if (octets.length >= 12 &&
        octets[0] == 0x52 &&
        octets[1] == 0x49 &&
        octets[2] == 0x46 &&
        octets[3] == 0x46 &&
        octets[8] == 0x57 &&
        octets[9] == 0x45 &&
        octets[10] == 0x42 &&
        octets[11] == 0x50) {
      return FormatImage.webp;
    }
    return FormatImage.inconnu;
  }

  /// Extension et type MIME correspondant à un format détecté.
  static (String, String) _extensionEtMime(FormatImage format) {
    switch (format) {
      case FormatImage.jpeg:
        return ('.jpg', 'image/jpeg');
      case FormatImage.png:
        return ('.png', 'image/png');
      case FormatImage.gif:
        return ('.gif', 'image/gif');
      case FormatImage.webp:
        return ('.webp', 'image/webp');
      case FormatImage.inconnu:
        return ('.jpg', 'image/jpeg');
    }
  }

  /// Prépare [octets] (issus de la galerie) pour l'envoi.
  ///
  /// [nomSource] est le nom renvoyé par le sélecteur ; il peut être vide, sans
  /// extension ou trompeur. Le contenu fait toujours foi.
  static AvatarPhotoResultat preparer({
    required Uint8List octets,
    String? nomSource,
    int tailleMaxOctets = kTailleMaxAvatarOctets,
  }) {
    if (octets.isEmpty) {
      return const AvatarPhotoErreur('Image vide : aucune photo à envoyer.');
    }

    final format = detecterFormat(octets);

    // Format déjà géré par le serveur ET taille raisonnable : on garde les
    // octets d'origine (pas de réencodage inutile → pas de perte de qualité,
    // pas d'animation GIF détruite).
    if (format != FormatImage.inconnu && octets.length <= tailleMaxOctets) {
      final (extension, mime) = _extensionEtMime(format);
      return AvatarPhotoPreparee(
        octets: octets,
        nomFichier: _nomFichier(nomSource, extensionParDefaut: extension),
        mimeType: mime,
        recompressee: false,
      );
    }

    // Sinon : réencodage réel (compression), en JPEG.
    final compresse = _compresser(octets, tailleMaxOctets: tailleMaxOctets);
    if (compresse == null) {
      return const AvatarPhotoErreur(
        "Format d'image non pris en charge. Choisissez une photo au format "
        'JPEG, PNG, GIF ou WEBP.',
      );
    }

    return AvatarPhotoPreparee(
      octets: compresse,
      nomFichier: _nomFichier(nomSource, extensionParDefaut: '.jpg'),
      mimeType: 'image/jpeg',
      recompressee: true,
    );
  }

  /// Réencode en JPEG sous [tailleMaxOctets], en baissant la qualité si besoin.
  ///
  /// `null` si le décodage est impossible (format réellement illisible).
  static Uint8List? _compresser(
    Uint8List octets, {
    required int tailleMaxOctets,
  }) {
    img.Image? decode = img.decodeImage(octets);
    if (decode == null) return null;

    // Respecte l'orientation EXIF (photos prises en portrait).
    decode = img.bakeOrientation(decode);

    // Réduction du côté long : un avatar s'affiche au maximum en 120 px.
    if (decode.width > kCoteMaxAvatar || decode.height > kCoteMaxAvatar) {
      decode = img.copyResize(
        decode,
        width: decode.width >= decode.height ? kCoteMaxAvatar : null,
        height: decode.height > decode.width ? kCoteMaxAvatar : null,
      );
    }

    Uint8List? meilleur;
    for (final qualite in const <int>[92, 82, 72, 62, 52, 42, 32]) {
      final encode = Uint8List.fromList(img.encodeJpg(decode, quality: qualite));
      meilleur = encode;
      if (encode.length <= tailleMaxOctets) break;
    }
    return meilleur;
  }

  /// Construit un nom de fichier sûr, toujours avec une extension acceptée.
  ///
  /// Nettoie le nom d'origine (espaces, caractères douteux, chemin résiduel)
  /// et remplace une extension absente ou non acceptée par l'extension réelle.
  static String _nomFichier(
    String? nomSource, {
    required String extensionParDefaut,
  }) {
    var base = (nomSource ?? '').trim();
    if (base.isEmpty) base = 'avatar';

    // Sécurité : jamais de séparateur de chemin (path traversal).
    base = base.replaceAll(RegExp(r'[\\/]+'), '_');
    base = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    base = base.replaceFirst(RegExp(r'^[.\s_]+'), '');
    if (base.isEmpty) base = 'avatar';

    // Longueur raisonnable (le nom est stocké côté serveur).
    if (base.length > 60) base = base.substring(0, 60);

    // L'extension doit refléter le CONTENU détecté (magic bytes), jamais le
    // nom d'origine : une photo JPEG nommée « .png » serait enregistrée avec
    // un type MIME erroné côté serveur.
    final point = base.lastIndexOf('.');
    if (point > 0) base = base.substring(0, point);
    if (base.isEmpty) base = 'avatar';
    return '$base$extensionParDefaut';
  }
}
