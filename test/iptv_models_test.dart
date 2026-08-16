import 'package:flutter_test/flutter_test.dart';
import 'package:slideup/features/iptv/models/iptv_models.dart';

void main() {
  group('IptvChannel JSON round-trip', () {
    test('round-trips all fields', () {
      const channel = IptvChannel(
        id: 'p1_abc',
        playlistId: 'p1',
        name: 'News TV',
        url: 'http://stream.example.com/news.m3u8',
        logo: 'http://x/logo.png',
        group: 'News',
        tvgId: 'news.id',
        tvgName: 'News 24',
        country: 'US',
        language: 'en',
        audioOnly: false,
        isFavorite: true,
        position: 7,
      );

      final json = channel.toJson();
      final restored = IptvChannel.fromJson(json);

      expect(restored.id, channel.id);
      expect(restored.playlistId, channel.playlistId);
      expect(restored.name, channel.name);
      expect(restored.url, channel.url);
      expect(restored.logo, channel.logo);
      expect(restored.group, 'News');
      expect(restored.tvgId, 'news.id');
      expect(restored.tvgName, 'News 24');
      expect(restored.country, 'US');
      expect(restored.language, 'en');
      expect(restored.audioOnly, isFalse);
      expect(restored.isFavorite, isTrue);
      expect(restored.position, 7);
      expect(restored.displayName, 'News 24');
    });

    test('uses grp column key and falls back to group', () {
      final json = {
        'id': 'x',
        'playlistId': 'p',
        'name': 'Radio',
        'url': 'http://x/radio.mp3',
        'grp': 'Music',
        'audioOnly': 1,
        'isFavorite': 0,
        'position': 0,
      };
      final restored = IptvChannel.fromJson(json);
      expect(restored.group, 'Music');
      expect(restored.audioOnly, isTrue);
    });

    test('defaults missing fields', () {
      final restored = IptvChannel.fromJson(const {
        'id': 'x',
        'playlistId': 'p',
        'name': 'N',
        'url': 'http://x',
      });
      expect(restored.group, '');
      expect(restored.logo, isNull);
      expect(restored.audioOnly, isFalse);
      expect(restored.isFavorite, isFalse);
      expect(restored.position, 0);
      expect(restored.displayName, 'N');
    });
  });

  group('IptvPlaylist JSON round-trip', () {
    test('round-trips a url playlist', () {
      final playlist = IptvPlaylist(
        id: 'pl',
        name: 'My List',
        sourceType: IptvSourceType.xtream,
        source: 'http://host:8000',
        username: 'user',
        password: 'pass',
        language: 'Hindi',
        channelCount: 120,
        groupCount: 5,
        lastUpdated: DateTime(2026, 1, 1, 12, 30),
        createdAt: DateTime(2025, 12, 1),
        isFavorite: true,
      );

      final restored = IptvPlaylist.fromJson(playlist.toJson());

      expect(restored.id, 'pl');
      expect(restored.name, 'My List');
      expect(restored.sourceType, IptvSourceType.xtream);
      expect(restored.source, 'http://host:8000');
      expect(restored.username, 'user');
      expect(restored.password, 'pass');
      expect(restored.language, 'Hindi');
      expect(restored.channelCount, 120);
      expect(restored.groupCount, 5);
      expect(restored.lastUpdated, DateTime(2026, 1, 1, 12, 30));
      expect(restored.createdAt, DateTime(2025, 12, 1));
      expect(restored.isFavorite, isTrue);
      expect(restored.sourceLabel, 'XTream');
    });

    test('defaults when fields missing', () {
      final restored = IptvPlaylist.fromJson(const {
        'id': 'pl',
        'name': 'X',
        'sourceType': 0,
        'source': 'http://x/list.m3u',
      });
      expect(restored.channelCount, 0);
      expect(restored.groupCount, 0);
      expect(restored.username, isNull);
      expect(restored.lastUpdated, isNull);
      expect(restored.isFavorite, isFalse);
      expect(restored.sourceLabel, 'M3U URL');
    });

    test('invalid sourceType index falls back to url', () {
      final restored = IptvPlaylist.fromJson(const {
        'id': 'pl',
        'name': 'X',
        'sourceType': 99,
        'source': 'http://x',
      });
      expect(restored.sourceType, IptvSourceType.url);
    });
  });

  group('IptvGroup', () {
    test('round-trips', () {
      const group = IptvGroup(name: 'News', channelCount: 4);
      final restored = IptvGroup.fromJson(group.toJson());
      expect(restored.name, 'News');
      expect(restored.channelCount, 4);
    });
  });

  group('iptvChannelId', () {
    test('is stable and playlist-scoped', () {
      final a = iptvChannelId('p1', 'http://x/a.m3u8');
      final b = iptvChannelId('p1', 'http://x/a.m3u8');
      final c = iptvChannelId('p2', 'http://x/a.m3u8');
      final d = iptvChannelId('p1', 'http://x/b.m3u8');
      expect(a, b);
      expect(a, isNot(c));
      expect(a, isNot(d));
      expect(a, startsWith('p1_'));
    });
  });
}