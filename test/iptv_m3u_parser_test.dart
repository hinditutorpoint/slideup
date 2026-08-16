import 'package:flutter_test/flutter_test.dart';
import 'package:slideup/features/iptv/models/iptv_models.dart';
import 'package:slideup/features/iptv/services/m3u_parser.dart';

void main() {
  group('M3uParser', () {
    test('parses a full playlist with groups, logos and audio detection', () {
      const content = '''
#EXTM3U
#EXTINF:-1 tvg-id="1" tvg-name="News TV" tvg-logo="http://x/logo.png" group-title="News",News TV
http://stream.example.com/news.m3u8
#EXTINF:-1 tvg-id="2" tvg-name="Jazz FM" group-title="Music",
http://stream.example.com/jazz.mp3
#EXTGRP:Sports
#EXTINF:-1 tvg-logo="http://x/s.png" group-title="Sports",Sports Channel
http://stream.example.com/sports.ts
#EXTINF:-1,Missing URL
''';

      final channels = M3uParser.parse(content: content, playlistId: 'p1');

      expect(channels.length, 3);

      final news = channels[0];
      expect(news.name, 'News TV');
      expect(news.tvgName, 'News TV');
      expect(news.logo, 'http://x/logo.png');
      expect(news.group, 'News');
      expect(news.audioOnly, isFalse);
      expect(news.id, startsWith('p1_'));

      final jazz = channels[1];
      expect(jazz.name, 'Jazz FM');
      expect(jazz.group, 'Music');
      expect(jazz.audioOnly, isTrue);
      expect(jazz.position, 1);

      final sports = channels[2];
      expect(sports.name, 'Sports Channel');
      expect(sports.group, 'Sports');
    });

    test('inherits defaultLanguage when tvg-language is absent', () {
      const content = '''
#EXTM3U
#EXTINF:-1 tvg-id="1" group-title="News",News TV
http://stream.example.com/news.m3u8
#EXTINF:-1 tvg-id="2" tvg-language="English" group-title="News",Talk
http://stream.example.com/talk.m3u8
''';

      final channels = M3uParser.parse(
        content: content,
        playlistId: 'p',
        defaultLanguage: 'Hindi',
      );
      expect(channels[0].language, 'Hindi');
      expect(channels[1].language, 'English');
    });

    test('uses EXTGRP when group-title is absent', () {
      const content = '''
#EXTM3U
#EXTGRP:Documentaries
#EXTINF:-1,Doc Channel
http://stream.example.com/doc.m3u8
''';

      final channels = M3uParser.parse(content: content, playlistId: 'p');
      expect(channels.length, 1);
      expect(channels.first.group, 'Documentaries');
    });

    test('falls back to URL-derived name and Ungrouped', () {
      const content = '''
#EXTM3U
#EXTINF:-1,
http://stream.example.com/plain.m3u8
''';

      final channels = M3uParser.parse(content: content, playlistId: 'p');
      expect(channels.length, 1);
      expect(channels.first.name, 'plain.m3u8');
      expect(channels.first.group, 'Ungrouped');
      expect(channels.first.audioOnly, isFalse);
    });

    test('returns empty list for malformed / empty content', () {
      expect(M3uParser.parse(content: '', playlistId: 'p'), isEmpty);
      expect(M3uParser.parse(content: 'garbage\nmore\n', playlistId: 'p'),
          isEmpty);
    });

    test('decodes HTML entities in names and attributes', () {
      const content = '''
#EXTM3U
#EXTINF:-1 tvg-name="News &amp; Weather" group-title="News &amp; World",News &amp; Weather
http://stream.example.com/n.m3u8
''';

      final channels = M3uParser.parse(content: content, playlistId: 'p');
      expect(channels.first.name, 'News & Weather');
      expect(channels.first.tvgName, 'News & Weather');
      expect(channels.first.group, 'News & World');
    });

    test('skips comments and unusable lines', () {
      const content = '''
#EXTM3U
#EXTVLCOPT:http-referrer=http://x
#KODIPROP:inputstream=inputstream.adaptive
not a url
#EXTINF:-1,Good Channel
http://stream.example.com/good.m3u8
''';

      final channels = M3uParser.parse(content: content, playlistId: 'p');
      expect(channels.length, 1);
      expect(channels.first.name, 'Good Channel');
    });
  });

  group('XtreamClient', () {
    test('normalizes server URLs', () {
      expect(XtreamClient.normalizeServer('example.com:8080'),
          'http://example.com:8080');
      expect(XtreamClient.normalizeServer('https://x.com/'),
          'https://x.com');
      expect(XtreamClient.normalizeServer('http://x.com'), 'http://x.com');
    });

    test('builds m3u export URI', () {
      final uri = XtreamClient.m3uUri(
        server: 'http://host:8000',
        username: 'u',
        password: 'p',
      );
      expect(uri.toString(),
          'http://host:8000/get.php?username=u&password=p&type=m3u_plus&output=ts');
    });

    test('hasCredentials requires all three', () {
      expect(
        XtreamClient.hasCredentials(
            server: 'x', username: 'u', password: 'p'),
        isTrue,
      );
      expect(
        XtreamClient.hasCredentials(
            server: '', username: 'u', password: 'p'),
        isFalse,
      );
      expect(
        XtreamClient.hasCredentials(
            server: 'x', username: '', password: 'p'),
        isFalse,
      );
    });
  });

  group('groupChannels', () {
    test('collapses channels into sorted groups', () {
      final channels = [
        const IptvChannel(id: '1', playlistId: 'p', name: 'a', url: 'u1'),
        const IptvChannel(
            id: '2',
            playlistId: 'p',
            name: 'b',
            url: 'u2',
            group: 'Music'),
        const IptvChannel(
            id: '3',
            playlistId: 'p',
            name: 'c',
            url: 'u3',
            group: 'News'),
        const IptvChannel(
            id: '4',
            playlistId: 'p',
            name: 'd',
            url: 'u4',
            group: 'Music'),
      ];

      final groups = groupChannels(channels);
      expect(groups.length, 3);
      expect(groups[0].name, 'Music');
      expect(groups[0].channelCount, 2);
      expect(groups[1].name, 'News');
      expect(groups[2].name, 'Ungrouped');
    });
  });
}