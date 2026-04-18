class ContactModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final bool isRegistered; // Si le contact utilise l'app
  
  ContactModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.photoUrl,
    this.isRegistered = false,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? 'Contact',
      phone: json['phone'],
      email: json['email'],
      photoUrl: json['photoUrl'] ?? json['photo_url'],
      isRegistered: json['isRegistered'] ?? json['is_registered'] ?? false,
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
    };
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
