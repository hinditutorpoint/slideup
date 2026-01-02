class Playlist {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> mediaIds;
  final String? thumbnailPath;
  final bool isLocked;
  final String? passwordHash;

  Playlist({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.mediaIds = const [],
    this.thumbnailPath,
    this.isLocked = false,
    this.passwordHash,
  });

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? mediaIds,
    String? thumbnailPath,
    bool? isLocked,
    String? passwordHash,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mediaIds: mediaIds ?? this.mediaIds,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isLocked: isLocked ?? this.isLocked,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'mediaIds': mediaIds.join(','),
      'thumbnailPath': thumbnailPath,
      'isLocked': isLocked ? 1 : 0,
      'passwordHash': passwordHash,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      mediaIds: (json['mediaIds'] as String).isEmpty
          ? []
          : (json['mediaIds'] as String).split(','),
      thumbnailPath: json['thumbnailPath'] as String?,
      isLocked: json['isLocked'] == 1,
      passwordHash: json['passwordHash'] as String?,
    );
  }
}
