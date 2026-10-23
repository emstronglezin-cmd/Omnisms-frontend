// ─────────────────────────────────────────────────────────────────────────
// Avatar et images distantes — résolution du contrat réel du backend.
//
// CONTRAT RÉEL (vérifié côté serveur) :
//   • `POST /api/me/avatar`      → { success, avatarUrl: "data:image/png;base64,…" }
//   • `GET  /api/me`             → { …, avatar: "data:image/png;base64,…" }
//   • `GET  /api/contacts`       → { …, avatar: "data:image/png;base64,…" }
//   • `GET  /api/messages`       → conv.otherUserAvatar = "data:image/png;base64,…"
//   • avatar de groupe           → base64 également (Firestore)
//
// Le backend stocke donc les photos **en data URI base64**, pas en URL.
// Or `Image.network`, `NetworkImage` et `CachedNetworkImage` font une requête
// HTTP : appelés avec « data:image/png;base64,… », ils échouent et l'on
// retombe sur l'avatar d'initiales. C'était la cause de l'absence des photos
// dans l'APK alors que la PWA (balise <img src="data:…">) les affichait.
//
// Ce composant est désormais le SEUL point d'affichage des avatars :
//   • data URI    → décodage base64 + `Image.memory` (aucune requête réseau) ;
//   • URL http(s) → `CachedNetworkImage` (cache disque, une seule requête) ;
//   • chemin /x   → préfixé par l'URL du backend ;
//   • absent      → initiales (jamais un message d'erreur).
//
// Aucune donnée personnelle ni jeton n'est journalisé.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../services/cache_service.dart';

/// Nature d'une valeur d'avatar renvoyée par le backend.
enum AvatarKind {
  /// `data:image/…;base64,…`
  dataUri,

  /// URL absolue `http(s)://…`
  remoteUrl,

  /// Chemin relatif (`/uploads/…`) — résolu avec l'URL du backend.
  relativePath,

  /// Valeur absente : initiales.
  none,

  /// Format inconnu : initiales (jamais d'erreur affichée à l'utilisateur).
  unsupported,
}

/// Résolution pure du contrat avatar — testable sans widget ni réseau.
class AvatarValue {
  const AvatarValue._(this.raw, this.kind);

  final String? raw;
  final AvatarKind kind;

  /// Analyse une valeur renvoyée par l'API.
  factory AvatarValue.parse(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const AvatarValue._(null, AvatarKind.none);
    }
    if (trimmed.startsWith('data:image/') && trimmed.contains(';base64,')) {
      return AvatarValue._(trimmed, AvatarKind.dataUri);
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return AvatarValue._(trimmed, AvatarKind.remoteUrl);
    }
    if (trimmed.startsWith('/')) {
      return AvatarValue._(trimmed, AvatarKind.relativePath);
    }
    return const AvatarValue._(null, AvatarKind.unsupported);
  }

  /// Vrai si l'on dispose d'une image exploitable.
  bool get hasImage => kind == AvatarKind.dataUri || kind == AvatarKind.remoteUrl;

  /// URL exploitable par un client HTTP (chemins relatifs résolus).
  ///
  /// `null` pour les data URI : il ne faut SURTOUT pas les passer à
  /// `Image.network`, c'est précisément le bug d'origine.
  String? get httpUrl {
    switch (kind) {
      case AvatarKind.remoteUrl:
        return raw;
      case AvatarKind.relativePath:
        return '${ApiConfig.baseUrl}$raw';
      case AvatarKind.dataUri:
      case AvatarKind.none:
      case AvatarKind.unsupported:
        return null;
    }
  }

  /// Octets décodés d'un data URI (`null` si ce n'en est pas un ou si le
  /// contenu est corrompu).
  Uint8List? get bytes {
    if (kind != AvatarKind.dataUri) return null;
    return AvatarBytesCache.instance.decode(raw!);
  }

  static const String _dataUriPrefix = 'data:image/';
  static const String _base64Marker = ';base64,';

  /// Vrai pour « data:image/png;base64,… ».
  static bool isDataUri(String? value) =>
      value != null &&
      value.startsWith(_dataUriPrefix) &&
      value.contains(_base64Marker);
}

/// Mémoire tampon des data URI déjà décodés.
///
/// Sans cela, une liste de 30 avatars redécoderait 30 chaînes base64 à chaque
/// reconstruction (jank au défilement). Les octets sont conservés en mémoire,
/// jamais sur le disque : aucune photo n'est stockée dans un fichier.
class AvatarBytesCache {
  AvatarBytesCache._();

  static final AvatarBytesCache instance = AvatarBytesCache._();

  /// Nombre maximum d'images conservées (≈ 40 × 60 Ko au pire).
  static const int maxEntries = 40;

  final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// Décode un data URI (avec mémoïsation) ; `null` si le contenu est invalide.
  Uint8List? decode(String dataUri) {
    final cached = _cache[dataUri];
    if (cached != null) return cached;

    Uint8List? bytes;
    try {
      final marker = dataUri.indexOf(';base64,');
      final payload = dataUri.substring(marker + ';base64,'.length);
      bytes = base64Decode(payload);
    } catch (_) {
      return null; // image illisible : on affichera les initiales
    }
    if (bytes.isEmpty) return null;

    if (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first); // éviction FIFO
    }
    _cache[dataUri] = bytes;
    return bytes;
  }

  /// Vide la mémoire tampon (utile à la déconnexion).
  void clear() => _cache.clear();

  /// Nombre d'entrées en mémoire (tests).
  int get length => _cache.length;
}

/// Avatar utilisateur : data URI, URL distante ou initiales.
///
/// Remplace les `Image.network(...)` et `CachedNetworkImage(...)` utilisés
/// jusqu'ici pour les photos de profil.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.backgroundColor,
    this.isGroup = false,
    this.cacheVersion,
    this.border,
    this.fallback,
  });

  /// Valeur brute renvoyée par l'API (`avatar`, `otherUserAvatar`, data URI…).
  final String? imageUrl;

  /// Nom affiché — sert aux initiales de repli et à la couleur.
  final String name;

  /// Diamètre de l'avatar.
  final double size;

  /// Couleur de fond des initiales (dérivée du nom par défaut).
  final Color? backgroundColor;

  /// Affiche une icône de groupe plutôt qu'une initiale en cas d'absence.
  final bool isGroup;

  /// Change uniquement lorsque la photo est réellement remplacée : permet
  /// d'invalider le cache disque d'une URL RESTÉE IDENTIQUE.
  final int? cacheVersion;

  /// Bordure optionnelle (ex. cercle blanc autour de l'avatar).
  final BoxBorder? border;

  /// Repli personnalisé (ex. avatar thématisé d'un écran). Par défaut :
  /// initiales du nom, ou icône de groupe.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final value = AvatarValue.parse(imageUrl);
    final Widget fallback = this.fallback ??
        _InitialsAvatar(
          name: name,
          size: size,
          isGroup: isGroup,
          backgroundColor: backgroundColor,
        );

    Widget content;
    if (value.kind == AvatarKind.dataUri) {
      final bytes = value.bytes;
      content = bytes == null
          ? fallback
          : Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // Une image corrompue n'affiche jamais d'icône « cassée »…
              errorBuilder: (_, error, ___) {
                // …mais l'échec n'est JAMAIS masqué : on le journalise
                // (l'interface, elle, reste propre).
                // Règle : pas d'URL inventée, pas d'échec silencieux.
                debugPrint('[Avatar] image mémoire illisible ($name): $error');
                return fallback;
              },
            );
    } else if (value.kind == AvatarKind.remoteUrl ||
        value.kind == AvatarKind.relativePath) {
      final url = value.httpUrl!;
      content = CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheManager: CacheService.imageCache,
        // Clé de cache dérivée de l'URL (+ version) : deux utilisateurs
        // différents ont deux URL différentes, donc deux entrées distinctes.
        // Aucune clé partagée : impossible d'afficher la photo d'un autre.
        cacheKey: cacheVersion == null ? '$url#${url.hashCode}' : '$url#v$cacheVersion',
        placeholder: (context, _) => _buildPlaceholder(fallback),
        errorWidget: (_, url, error) {
          // Échec de chargement d'une photo distante : journalisé, jamais
          // masqué (l'UI affiche le repli, le journal garde la cause).
          debugPrint('[Avatar] échec de chargement $url : $error');
          return fallback;
        },
        fadeInDuration: const Duration(milliseconds: 150),
      );
    } else {
      content = fallback;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Un repli personnalisé apporte sa propre couleur de fond.
        color: this.fallback != null
            ? Colors.transparent
            : (backgroundColor ?? _colorFromName(name)),
        border: border,
      ),
      child: ClipOval(child: content),
    );
  }

  /// Pendant le chargement d'une image distante : les initiales, plus une
  /// indication de chargement si l'avatar est assez grand pour la porter.
  Widget _buildPlaceholder(Widget fallback) {
    if (size < 72) return fallback;
    return Stack(
      alignment: Alignment.center,
      children: [
        fallback,
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
      ],
    );
  }

  /// Couleur dérivée du nom : le même contact garde toujours la même couleur.
  static Color _colorFromName(String name) {
    const colors = <Color>[
      Color(0xFF667eea),
      Color(0xFF764ba2),
      Color(0xFFf093fb),
      Color(0xFF4facfe),
      Color(0xFF00f2fe),
      Color(0xFF43e97b),
      Color(0xFF38f9d7),
      Color(0xFFfa709a),
      Color(0xFFfee140),
      Color(0xFFfccb90),
    ];
    final hash = name.codeUnits.fold<int>(0, (prev, el) => prev + el);
    return colors[hash.abs() % colors.length];
  }
}

/// Avatar de repli : initiale du nom (ou icône de groupe).
class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.name,
    required this.size,
    required this.isGroup,
    this.backgroundColor,
  });

  final String name;
  final double size;
  final bool isGroup;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (isGroup) {
      return Icon(Icons.group, size: size * 0.5, color: Colors.white);
    }
    final initials = _initialsOf(name);
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.elementAt(1)[0]).toUpperCase();
  }
}

/// Image quelconque (pièce jointe, image de message) : data URI ou URL.
class SmartImage extends StatelessWidget {
  const SmartImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final value = AvatarValue.parse(imageUrl);

    Widget child;
    if (value.kind == AvatarKind.dataUri) {
      final bytes = value.bytes;
      child = bytes == null
          ? (errorWidget ?? _defaultError())
          : Image.memory(
              bytes,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (_, error, ___) {
                debugPrint('[Avatar] image mémoire illisible: $error');
                return errorWidget ?? _defaultError();
              },
            );
    } else {
      final url = value.httpUrl;
      if (url == null) return errorWidget ?? _defaultError();
      child = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        cacheManager: CacheService.imageCache,
        placeholder: (context, _) =>
            placeholder ??
            Container(
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
        errorWidget: (_, url, error) {
          debugPrint('[Avatar] échec de chargement $url : $error');
          return errorWidget ?? _defaultError();
        },
        fadeInDuration: const Duration(milliseconds: 150),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  static Widget _defaultError() => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, color: Colors.grey, size: 32),
      );
}
