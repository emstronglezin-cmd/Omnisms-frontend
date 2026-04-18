class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final List<String> memberIds;
  final String creatorId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.memberIds,
    required this.creatorId,
    required this.createdAt,
    this.updatedAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? 'Groupe',
      description: json['description'],
      photoUrl: json['photoUrl'] ?? json['photo_url'],
      memberIds: List<String>.from(json['memberIds'] ?? json['member_ids'] ?? []),
      creatorId: json['creatorId'] ?? json['creator_id'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'photoUrl': photoUrl,
      'memberIds': memberIds,
      'creatorId': creatorId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  int get memberCount => memberIds.length;
}
