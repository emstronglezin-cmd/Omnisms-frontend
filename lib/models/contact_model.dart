class ContactModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final bool isRegistered; // Si le contact utilise l'app

  /// Identifiant du compte OmniSMS associé (UID Firestore), quand le contact
  /// possède un compte. `GET /api/contacts` le renvoie sous `registeredUserId`
  /// (et `userId`) ; il est `null` pour un contact sans compte (SMS seul).
  ///
  /// Sert UNIQUEMENT à désigner un membre de groupe (`POST /api/groups`
  /// attend des UID : le backend fait `[...new Set([uid, ...members])]`).
  final String? userId;

  /// Provenance renvoyée par le backend (`google`, `vcf`, `manual`, null).
  /// Le frontend ne fait que l'afficher : la déduplication et la
  /// normalisation restent côté backend.
  final String? source;

  ContactModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.photoUrl,
    this.isRegistered = false,
    this.source,
    this.userId,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? 'Contact',
      phone: json['phone'],
      email: json['email'],
      // Le backend stocke la photo sous `avatar` (contacts Google inclus).
      photoUrl: json['photoUrl'] ?? json['photo_url'] ?? json['avatar'],
      // `isOnOmniSms` est le champ renvoyé par /api/contacts (sync + Google).
      isRegistered: json['isRegistered'] ??
          json['is_registered'] ??
          json['isOnOmniSms'] ??
          false,
      source: json['source']?.toString(),
      // `GET /api/contacts` (routes/contacts.v2.js) ne renvoie PAS de champ
      // `id` : sans ces clés dérivées, `id` vaut '' pour TOUS les contacts
      // synchronisés et une sélection « unique » en sélectionne plusieurs.
      userId: (json['registeredUserId'] ?? json['userId'] ?? json['uid'])
          ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'photoUrl': photoUrl,
      'isRegistered': isRegistered,
      if (source != null) 'source': source,
      if (userId != null) 'userId': userId,
    };
  }

  /// Contact importé depuis Google Contacts.
  bool get isGoogleContact => source == 'google';

  /// Contact sans compte OmniSMS associé (numéro externe).
  bool get isExternal => !isRegistered;

  /// Clé d'identification unique et STABLE pour l'interface (sélection,
  /// clés de liste).
  ///
  /// Cause du bug « un appui sélectionne tout » : `GET /api/contacts` ne
  /// renvoie pas de champ `id`, donc `id` valait `''` pour chaque contact
  /// synchronisé et un `Set<String>` d'identifiants ne contenait qu'un seul
  /// élément partagé par toutes les lignes.
  ///
  /// Ordre de priorité : `id` → UID du compte → numéro de téléphone → nom.
  /// Le numéro reste la clé de repli : c'est déjà celle utilisée pour ouvrir
  /// une conversation (`contacts_screen_v2.dart`).
  String get selectionKey {
    if (id.isNotEmpty) return id;
    final uid = userId?.trim();
    if (uid != null && uid.isNotEmpty) return uid;
    final p = phone?.trim();
    if (p != null && p.isNotEmpty) return p;
    return 'name:${name.trim().toLowerCase()}';
  }

  /// Identifiant à transmettre au backend pour ajouter ce contact à un groupe
  /// (`POST /api/groups` attend des UID de comptes).
  ///
  /// Renvoie `null` quand le contact n'a pas de compte OmniSMS : l'envoyer
  /// tel quel créerait un membre fantôme dans le groupe.
  String? get memberId {
    final uid = userId?.trim();
    if (uid != null && uid.isNotEmpty) return uid;
    // Un contact local (VCF/carnet) porte son numéro dans `id` : ce n'est pas
    // un UID, il ne peut donc pas servir d'identifiant de membre.
    return null;
  }

  String get displayName => name.isNotEmpty ? name : phone ?? 'Contact';
  String get initials {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
