class UserModel {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;

  /// Nom d'utilisateur (@pseudo) — obligatoire côté backend depuis la PWA :
  /// POST /api/auth/register exige `username`
  /// (2-50 caractères, lettres/chiffres/_ . - uniquement).
  final String? username;

  final bool isSubscribed;
  final bool premium;
  final num credits;

  /// Le backend renseigne `needsPhone` pour les comptes créés via Google
  /// sans numéro de téléphone : la PWA redirige alors vers les paramètres.
  final bool needsPhone;

  /// Numéro de téléphone vérifié par OTP ?
  ///
  /// Sémantique serveur (routes/auth.js, services/googleOAuth.js) :
  /// `phoneVerified: user.phoneVerified !== false` — un champ absent vaut
  /// donc VRAI. On reproduit exactement cette règle : seul un `false`
  /// explicite marque un compte en attente de vérification.
  ///
  /// Ce drapeau vient du SERVEUR. L'application ne le déduit jamais de
  /// l'écran affiché ni d'un état local.
  final bool phoneVerified;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.username,
    this.isSubscribed = false,
    this.premium = false,
    this.credits = 0,
    this.needsPhone = false,
    this.phoneVerified = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Libellé d'affichage : nom > email > téléphone > « Utilisateur ».
  /// Même ordre que `renderUserInfo()` dans la PWA.
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (email != null && email!.trim().isNotEmpty) return email!.trim();
    if (phone != null && phone!.trim().isNotEmpty) return phone!.trim();
    return 'Utilisateur';
  }

  /// Compte Premium (les deux drapeaux sont utilisés selon les routes).
  bool get isPremium => isSubscribed || premium;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return UserModel(
      id: (json['id'] ?? json['_id'] ?? json['uid'] ?? '').toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      // Contrat réel : `avatar` (GET /api/me) et `avatarUrl`
      // (POST /api/me/avatar). La valeur est un data URI base64 — jamais une
      // URL : l'affichage est géré par UserAvatar (widgets/common/avatar_image.dart).
      photoUrl: (json['photoUrl'] ??
          json['photo_url'] ??
          json['avatar'] ??
          json['avatarUrl'])
          ?.toString(),
      username: json['username']?.toString(),
      isSubscribed: json['isSubscribed'] == true || json['subscribed'] == true,
      premium: json['premium'] == true,
      credits: json['credits'] is num
          ? json['credits'] as num
          : num.tryParse(json['credits']?.toString() ?? '') ?? 0,
      needsPhone: json['needsPhone'] == true,
      phoneVerified: json['phoneVerified'] != false,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'username': username,
      'isSubscribed': isSubscribed,
      'premium': premium,
      'credits': credits,
      'needsPhone': needsPhone,
      'phoneVerified': phoneVerified,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? username,
    bool? isSubscribed,
    bool? premium,
    num? credits,
    bool? needsPhone,
    bool? phoneVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      username: username ?? this.username,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      premium: premium ?? this.premium,
      credits: credits ?? this.credits,
      needsPhone: needsPhone ?? this.needsPhone,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
