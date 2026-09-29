class ContactModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final bool isRegistered; // Si le contact utilise l'app

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
    };
  }

  /// Contact importé depuis Google Contacts.
  bool get isGoogleContact => source == 'google';

  /// Contact sans compte OmniSMS associé (numéro externe).
  bool get isExternal => !isRegistered;

  String get displayName => name.isNotEmpty ? name : phone ?? 'Contact';
  String get initials {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
