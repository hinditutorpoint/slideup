import 'dart:convert';

enum IptvSourceType { url, file, xtream }

IptvSourceType iptvSourceTypeFromIndex(int? index) {
  if (index == null || index < 0 || index >= IptvSourceType.values.length) {
    return IptvSourceType.url;
  }
  return IptvSourceType.values[index];
}

/// A single IPTV channel parsed from an M3U/Xtream playlist.
class IptvChannel {
  final String id;
  final String playlistId;
  final String name;
  final String url;
  final String? logo;
  final String group;
  final String? tvgId;
  final String? tvgName;
  final String? country;
  final String? language;
  final bool audioOnly;
  final bool isFavorite;
  final int position;

  const IptvChannel({
    required this.id,
    required this.playlistId,
    required this.name,
    required this.url,
    this.logo,
    this.group = '',
    this.tvgId,
    this.tvgName,
    this.country,
    this.language,
    this.audioOnly = false,
    this.isFavorite = false,
    this.position = 0,
  });

  IptvChannel copyWith({
    String? id,
    String? playlistId,
    String? name,
    String? url,
    String? logo,
    String? group,
    String? tvgId,
    String? tvgName,
    String? country,
    String? language,
    bool? audioOnly,
    bool? isFavorite,
    int? position,
  }) {
    return IptvChannel(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      name: name ?? this.name,
      url: url ?? this.url,
      logo: logo ?? this.logo,
      group: group ?? this.group,
      tvgId: tvgId ?? this.tvgId,
      tvgName: tvgName ?? this.tvgName,
      country: country ?? this.country,
      language: language ?? this.language,
      audioOnly: audioOnly ?? this.audioOnly,
      isFavorite: isFavorite ?? this.isFavorite,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playlistId': playlistId,
      'name': name,
      'url': url,
      'logo': logo,
      'grp': group,
      'tvgId': tvgId,
      'tvgName': tvgName,
      'country': country,
      'language': language,
      'audioOnly': audioOnly ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'position': position,
    };
  }

  factory IptvChannel.fromJson(Map<String, dynamic> json) {
    return IptvChannel(
      id: json['id'] as String,
      playlistId: json['playlistId'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      logo: json['logo'] as String?,
      group: (json['grp'] as String?) ?? (json['group'] as String?) ?? '',
      tvgId: json['tvgId'] as String?,
      tvgName: json['tvgName'] as String?,
      country: json['country'] as String?,
      language: json['language'] as String?,
      audioOnly: (json['audioOnly'] == 1 || json['audioOnly'] == true),
      isFavorite: (json['isFavorite'] == 1 || json['isFavorite'] == true),
      position: (json['position'] as int?) ?? 0,
    );
  }

  /// Display name: prefers tvgName, then the parsed name.
  String get displayName => tvgName ?? name;
}

/// A saved IPTV playlist (M3U URL, local file, or Xtream server).
class IptvPlaylist {
  final String id;
  final String name;
  final IptvSourceType sourceType;
  final String source;
  final String? username;
  final String? password;
  final String? language;
  final int channelCount;
  final int groupCount;
  final DateTime? lastUpdated;
  final DateTime createdAt;
  final bool isFavorite;

  const IptvPlaylist({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.source,
    this.username,
    this.password,
    this.language,
    this.channelCount = 0,
    this.groupCount = 0,
    this.lastUpdated,
    required this.createdAt,
    this.isFavorite = false,
  });

  IptvPlaylist copyWith({
    String? id,
    String? name,
    IptvSourceType? sourceType,
    String? source,
    String? username,
    String? password,
    String? language,
    int? channelCount,
    int? groupCount,
    DateTime? lastUpdated,
    DateTime? createdAt,
    bool? isFavorite,
  }) {
    return IptvPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      source: source ?? this.source,
      username: username ?? this.username,
      password: password ?? this.password,
      language: language ?? this.language,
      channelCount: channelCount ?? this.channelCount,
      groupCount: groupCount ?? this.groupCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sourceType': sourceType.index,
      'source': source,
      'username': username,
      'password': password,
      'language': language,
      'channelCount': channelCount,
      'groupCount': groupCount,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory IptvPlaylist.fromJson(Map<String, dynamic> json) {
    return IptvPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      sourceType: iptvSourceTypeFromIndex(json['sourceType'] as int?),
      source: json['source'] as String,
      username: json['username'] as String?,
      password: json['password'] as String?,
      language: json['language'] as String?,
      channelCount: (json['channelCount'] as int?) ?? 0,
      groupCount: (json['groupCount'] as int?) ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
              DateTime.now(),
      isFavorite: (json['isFavorite'] == 1 || json['isFavorite'] == true),
    );
  }

  /// Human readable label of the source type.
  String get sourceLabel {
    switch (sourceType) {
      case IptvSourceType.url:
        return 'M3U URL';
      case IptvSourceType.file:
        return 'Local file';
      case IptvSourceType.xtream:
        return 'XTream';
    }
  }
}

/// A channel group within a playlist.
class IptvGroup {
  final String name;
  final int channelCount;

  const IptvGroup({required this.name, required this.channelCount});

  Map<String, dynamic> toJson() =>
      {'name': name, 'channelCount': channelCount};

  factory IptvGroup.fromJson(Map<String, dynamic> json) => IptvGroup(
        name: json['name'] as String,
        channelCount: (json['channelCount'] as int?) ?? 0,
      );
}

/// Collapses a raw channel list into ordered groups.
List<IptvGroup> groupChannels(List<IptvChannel> channels) {
  final map = <String, int>{};
  for (final c in channels) {
    final g = c.group.trim().isEmpty ? 'Ungrouped' : c.group.trim();
    map[g] = (map[g] ?? 0) + 1;
  }
  final groups = map.entries.map((e) => IptvGroup(name: e.key, channelCount: e.value)).toList();
  groups.sort((a, b) => a.name.compareTo(b.name));
  return groups;
}

/// Stable channel id for a playlist + url.
String iptvChannelId(String playlistId, String url) {
  final hash = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
  return '${playlistId}_$hash';
}