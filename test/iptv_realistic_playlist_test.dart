import 'package:flutter_test/flutter_test.dart';
import 'package:slideup/features/iptv/services/m3u_parser.dart';

/// Realistic excerpt from https://iptv-org.github.io/iptv/languages/hin.m3u
const kRealisticHinM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="9XJalwa.in@SD" tvg-logo="https://xstreamcp-assets-msp.streamready.in/assets/LIVETV/LIVECHANNEL/LIVETV_LIVETVCHANNEL_9X_JALWA/images/LOGO_HD/image.png" group-title="Music",9X Jalwa (1080p)
https://b.jsrdn.com/strm/channels/9xjalwa/master.m3u8
#EXTINF:-1 tvg-id="AasthaBhajan.in@SD" tvg-logo="https://dtil.tmsimg.com/assets/s142514_ld_h15_aa.png?lock=720x540" http-user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36" group-title="Religious",Aastha Bhajan (576p)
#EXTVLCOPT:http-user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36
http://103.175.73.12:8080/live/339/master.m3u8
#EXTINF:-1 tvg-id="B4UHitz.in@SD" tvg-logo="" group-title="Music",B4U Hitz (576p)
http://115.42.65.142:9981/stream/channelid/1099703605
#EXTINF:-1 tvg-id="HareKrsnaTV.in@SD" tvg-logo="https://dtil.tmsimg.com/assets/s143102_ld_h15_aa.png?lock=720x540" group-title="Religious",Hare Krsna TV (1080p)
https://hktv.harekrsnatv.com/HKTV/HKWebApp/manifest.mpd
#EXTINF:-1 tvg-id="ColorsCineplex.in@SD" tvg-logo="https://xstreamcp-assets-msp.streamready.in/assets/LIVETV/LIVECHANNEL/LIVETV_LIVETVCHANNEL_COLORS_CINEPLEX/images/LOGO_HD/image.png" group-title="Movies",Colors Cineplex (576p)
http://103.122.249.134:8000/play/a058
#EXTINF:-1 tvg-id="AndyHaryana.in@SD" tvg-logo="https://i.imgur.com/rmCBD3e.png" group-title="Culture;Music",Andy Haryana (576p)
https://mumt03.tangotv.in/Dsly5z3HANDYHARYANA/index.m3u8
''';

void main() {
  test('parses a realistic iptv-org Hindi playlist excerpt', () {
    final channels = M3uParser.parse(content: kRealisticHinM3u, playlistId: 'hin');

    expect(channels.length, 6);

    // Standard entry with logo + group.
    final jalwa = channels[0];
    expect(jalwa.name, '9X Jalwa (1080p)');
    expect(jalwa.group, 'Music');
    expect(jalwa.logo, startsWith('https://'));
    expect(jalwa.audioOnly, isFalse);

    // Inline http-user-agent attribute + EXTVLCOPT line must not break parsing.
    final bhajan = channels[1];
    expect(bhajan.name, 'Aastha Bhajan (576p)');
    expect(bhajan.group, 'Religious');
    expect(bhajan.logo, startsWith('https://dtil'));
    expect(bhajan.url, 'http://103.175.73.12:8080/live/339/master.m3u8');

    // Empty tvg-logo="" -> null logo, extension-less URL still accepted.
    final b4u = channels[2];
    expect(b4u.name, 'B4U Hitz (576p)');
    expect(b4u.logo, isNull);
    expect(b4u.url, 'http://115.42.65.142:9981/stream/channelid/1099703605');

    // .mpd (DASH) stream accepted as video.
    final krsna = channels[3];
    expect(krsna.name, 'Hare Krsna TV (1080p)');
    expect(krsna.audioOnly, isFalse);

    // Extension-less HTTP URL accepted.
    final cineplex = channels[4];
    expect(cineplex.name, 'Colors Cineplex (576p)');
    expect(cineplex.url, 'http://103.122.249.134:8000/play/a058');

    // Semicolon-separated group kept as a single group string.
    final andy = channels[5];
    expect(andy.group, 'Culture;Music');
  });
}