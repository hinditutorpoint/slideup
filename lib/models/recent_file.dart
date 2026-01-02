class RecentFile {
  final String id;
  final String mediaId;
  final DateTime lastAccessed;
  final int? lastPosition; // For video/audio position in milliseconds
  final int accessCount;

  RecentFile({
    required this.id,
    required this.mediaId,
    required this.lastAccessed,
    this.lastPosition,
    this.accessCount = 1,
  });

  RecentFile copyWith({
    String? id,
    String? mediaId,
    DateTime? lastAccessed,
    int? lastPosition,
    int? accessCount,
  }) {
    return RecentFile(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      lastPosition: lastPosition ?? this.lastPosition,
      accessCount: accessCount ?? this.accessCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaId': mediaId,
      'lastAccessed': lastAccessed.toIso8601String(),
      'lastPosition': lastPosition,
      'accessCount': accessCount,
    };
  }

  factory RecentFile.fromJson(Map<String, dynamic> json) {
    return RecentFile(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String,
      lastAccessed: DateTime.parse(json['lastAccessed'] as String),
      lastPosition: json['lastPosition'] as int?,
      accessCount: json['accessCount'] as int? ?? 1,
    );
  }
}
