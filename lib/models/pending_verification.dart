import 'dart:convert';

/// Vérification de numéro en attente : l'utilisateur a un compte (ou un
/// brouillon de compte) mais le serveur exige encore la validation du
/// numéro par OTP avant d'ouvrir une session.
///
/// Ce qu'elle contient :
///   • le numéro à vérifier (normalisé) ;
///   • l'identifiant serveur de l'utilisateur, connu après inscription ;
///   • un éventuel jeton D'ATTENTE renvoyé par le serveur.
///
/// Ce qu'elle ne contient JAMAIS :
///   • le code OTP (saisi à l'écran, jamais persisté) ;
///   • un jeton d'accès utilisable — [pendingToken] est stocké à part du
///     jeton de session (`auth_token`) et n'ouvre aucun écran.
class PendingVerification {
  /// Numéro au format international (ex. `+22670123456`).
  final String phone;

  /// UID renvoyé par le serveur (inscription / échange Google), s'il existe.
  final String? userId;

  /// Jeton temporaire de vérification — JAMAIS un jeton d'accès.
  /// Il est transmis à `verify-otp` si le backend en a besoin, et n'est
  /// enregistré sous aucune clé de session.
  final String? pendingToken;

  /// Origine du parcours, pour les messages affichés à l'utilisateur.
  final VerificationOrigin origin;

  /// Horodatage de création (mémoire + persistance).
  final DateTime createdAt;

  PendingVerification({
    required this.phone,
    this.userId,
    this.pendingToken,
    this.origin = VerificationOrigin.signup,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  PendingVerification copyWith({
    String? phone,
    String? userId,
    String? pendingToken,
    VerificationOrigin? origin,
  }) {
    return PendingVerification(
      phone: phone ?? this.phone,
      userId: userId ?? this.userId,
      pendingToken: pendingToken ?? this.pendingToken,
      origin: origin ?? this.origin,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'phone': phone,
        if (userId != null) 'userId': userId,
        if (pendingToken != null) 'pendingToken': pendingToken,
        'origin': origin.name,
        'createdAt': createdAt.toIso8601String(),
      };

  static PendingVerification? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final phone = (map['phone'] ?? '').toString().trim();
    if (phone.isEmpty) return null;

    final originName = (map['origin'] ?? '').toString();
    final origin = VerificationOrigin.values.firstWhere(
      (o) => o.name == originName,
      orElse: () => VerificationOrigin.signup,
    );

    DateTime? created;
    final rawDate = map['createdAt']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      created = DateTime.tryParse(rawDate);
    }

    return PendingVerification(
      phone: phone,
      userId: (map['userId']?.toString().isEmpty ?? true)
          ? null
          : map['userId'].toString(),
      pendingToken: (map['pendingToken']?.toString().isEmpty ?? true)
          ? null
          : map['pendingToken'].toString(),
      origin: origin,
      createdAt: created,
    );
  }

  static PendingVerification? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw) as Object?);
    } catch (_) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() =>
      'PendingVerification(phone: $phone, origin: ${origin.name}, hasToken: ${pendingToken != null})';
}

/// Origine du parcours de vérification — influe uniquement sur les libellés.
enum VerificationOrigin {
  /// Inscription par téléphone / email + mot de passe.
  signup,

  /// Connexion d'un compte existant dont le numéro n'est pas vérifié.
  login,

  /// Compte Google nouvellement créé (ou existant non vérifié).
  google,
}
