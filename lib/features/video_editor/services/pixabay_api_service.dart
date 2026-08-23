import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:just_audio/just_audio.dart';
import 'package:slideup/core/constants/api.dart';
import '../models/video_edit_settings.dart';

class PixabayApiService {
  static final PixabayApiService _instance = PixabayApiService._internal();
  factory PixabayApiService() => _instance;
  PixabayApiService._internal();

  // 🔑 Replace with your Pixabay API Key
  // Get free API key from: https://pixabay.com/api/docs/
  static const String _imageBaseUrl = 'https://pixabay.com/api/';
  //static const String _musicBaseUrl =
  //'https://pixabay.com/api/videos/'; // Note: Pixabay music is limited

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, MusicTrack> _downloadedTracks = {};
  final Map<String, StockImage> _downloadedImages = {};

  String? _currentPlayingId;
  bool get isPlaying => _audioPlayer.playing;
  String? get currentPlayingId => _currentPlayingId;

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  // ═══════════════════════════════════════════════════════
  // ✅ FETCH IMAGES
  // ═══════════════════════════════════════════════════════

  Future<List<StockImage>> fetchImages({
    String query = '',
    ImageCategory category = ImageCategory.all,
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      if (!Api.isConfigured || Api.pixaBayKey.isEmpty) {
        debugPrint('⚠️ Pixabay key missing; returning development stock fallback');
        return _getMockStockImages(query, category);
      }

      final searchQuery = query.isNotEmpty
          ? query
          : _getCategoryQuery(category);

      final params = {
        'key': Api.pixaBayKey,
        'q': searchQuery,
        'page': page.toString(),
        'per_page': perPage.toString(),
        'image_type': 'photo',
        'safesearch': 'true',
      };

      if (category != ImageCategory.all && query.isEmpty) {
        params['category'] = _getCategoryName(category);
      }

      final uri = Uri.parse(_imageBaseUrl).replace(queryParameters: params);

      debugPrint('🖼️ Fetching images: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hits = data['hits'] as List? ?? [];

        final images = hits
            .map((hit) {
              try {
                return StockImage.fromPixabay(hit);
              } catch (e) {
                debugPrint('❌ Parse image error: $e');
                return null;
              }
            })
            .whereType<StockImage>()
            .toList();

        return await _updateImagesDownloadStatus(images);
      } else {
        debugPrint(
          '❌ Pixabay API error: ${response.statusCode} - ${response.body}',
        );
        return _getMockStockImages(query, category);
      }
    } catch (e) {
      debugPrint('❌ Fetch images error: $e');
      return _getMockStockImages(query, category);
    }
  }

  List<StockImage> _getMockStockImages(String query, ImageCategory category) {
    return List.generate(20, (index) {
      final id = 'stock_${category.name}_${index + 1}';
      return StockImage(
        id: id,
        title: '${category.name.toUpperCase()} Image ${index + 1}',
        photographer: 'Stock Artist ${index + 1}',
        thumbnailUrl: 'https://picsum.photos/400/300?random=${index + 10}',
        previewUrl: 'https://picsum.photos/800/600?random=${index + 10}',
        fullUrl: 'https://picsum.photos/1920/1080?random=${index + 10}',
        width: 1920,
        height: 1080,
        category: category,
        likes: (index + 1) * 42,
        downloads: (index + 1) * 120,
      );
    });
  }

  String _getCategoryQuery(ImageCategory category) {
    switch (category) {
      case ImageCategory.backgrounds:
        return 'background wallpaper';
      case ImageCategory.fashion:
        return 'fashion style';
      case ImageCategory.nature:
        return 'nature landscape';
      case ImageCategory.science:
        return 'science technology';
      case ImageCategory.education:
        return 'education learning';
      case ImageCategory.feelings:
        return 'emotions feelings';
      case ImageCategory.health:
        return 'health wellness';
      case ImageCategory.people:
        return 'people portrait';
      case ImageCategory.places:
        return 'places destination';
      case ImageCategory.animals:
        return 'animals wildlife';
      case ImageCategory.food:
        return 'food cooking';
      case ImageCategory.computer:
        return 'computer technology';
      case ImageCategory.sports:
        return 'sports fitness';
      case ImageCategory.transportation:
        return 'transportation vehicle';
      case ImageCategory.travel:
        return 'travel adventure';
      case ImageCategory.buildings:
        return 'buildings architecture';
      case ImageCategory.business:
        return 'business office';
      case ImageCategory.music:
        return 'music instrument';
      default:
        return 'popular';
    }
  }

  String _getCategoryName(ImageCategory category) {
    switch (category) {
      case ImageCategory.backgrounds:
        return 'backgrounds';
      case ImageCategory.fashion:
        return 'fashion';
      case ImageCategory.nature:
        return 'nature';
      case ImageCategory.science:
        return 'science';
      case ImageCategory.education:
        return 'education';
      case ImageCategory.feelings:
        return 'feelings';
      case ImageCategory.health:
        return 'health';
      case ImageCategory.people:
        return 'people';
      case ImageCategory.places:
        return 'places';
      case ImageCategory.animals:
        return 'animals';
      case ImageCategory.food:
        return 'food';
      case ImageCategory.computer:
        return 'computer';
      case ImageCategory.sports:
        return 'sports';
      case ImageCategory.transportation:
        return 'transportation';
      case ImageCategory.travel:
        return 'travel';
      case ImageCategory.buildings:
        return 'buildings';
      case ImageCategory.business:
        return 'business';
      case ImageCategory.music:
        return 'music';
      default:
        return '';
    }
  }

  Future<List<StockImage>> _updateImagesDownloadStatus(
    List<StockImage> images,
  ) async {
    return Future.wait(
      images.map((img) async {
        try {
          final isDownloaded = await isImageDownloaded(img.id);
          final localPath = isDownloaded
              ? await getImageLocalPath(img.id)
              : null;
          return img.copyWith(isDownloaded: isDownloaded, localPath: localPath);
        } catch (e) {
          return img;
        }
      }),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ FETCH MUSIC (Pixabay Audio API)
  // Endpoint: https://pixabay.com/api/audio/
  // ═══════════════════════════════════════════════════════

  static const String _musicBaseUrl = 'https://pixabay.com/api/audio/';

  Future<List<MusicTrack>> fetchMusic({
    String query = '',
    MusicCategory category = MusicCategory.all,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      if (!Api.isConfigured || Api.pixaBayKey.isEmpty) {
        debugPrint('⚠️ Pixabay key missing; returning mock music tracks');
        return _getMockMusicTracks(query, category);
      }

      final params = {
        'key': Api.pixaBayKey,
        'q': query.isNotEmpty ? query : 'music',
        'page': page.toString(),
        'per_page': perPage.toString(),
        'safesearch': 'true',
      };

      final uri = Uri.parse(_musicBaseUrl).replace(queryParameters: params);

      debugPrint('🎵 Fetching Pixabay music: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hits = data['hits'] as List? ?? [];

        final tracks = hits
            .map((hit) {
              try {
                return MusicTrack.fromPixabay(hit);
              } catch (e) {
                debugPrint('❌ Parse music track error: $e');
                return null;
              }
            })
            .whereType<MusicTrack>()
            .toList();

        return await _updateMusicDownloadStatus(tracks);
      } else {
        debugPrint('❌ Pixabay Music API error: ${response.statusCode}');
        return _getMockMusicTracks(query, category);
      }
    } catch (e) {
      debugPrint('❌ Fetch music error: $e');
      return _getMockMusicTracks(query, category);
    }
  }

  List<MusicTrack> _getMockMusicTracks(String query, MusicCategory category) {
    final allTracks = [
      MusicTrack(
        id: '1',
        title: 'Summer Vibes',
        artist: 'Chill Masters',
        albumArt: 'https://picsum.photos/200?random=1',
        duration: const Duration(minutes: 3, seconds: 24),
        previewUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        category: MusicCategory.ambient,
        downloads: 1250,
        tags: ['chill', 'summer', 'relaxing'],
      ),
      MusicTrack(
        id: '2',
        title: 'Energy Boost',
        artist: 'Beat Factory',
        albumArt: 'https://picsum.photos/200?random=2',
        duration: const Duration(minutes: 2, seconds: 45),
        previewUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        category: MusicCategory.electronic,
        downloads: 2340,
        tags: ['energetic', 'workout', 'upbeat'],
      ),
      MusicTrack(
        id: '3',
        title: 'Emotional Piano',
        artist: 'Piano Dreams',
        albumArt: 'https://picsum.photos/200?random=3',
        duration: const Duration(minutes: 4, seconds: 12),
        previewUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        category: MusicCategory.classical,
        downloads: 890,
        tags: ['emotional', 'piano', 'cinematic'],
      ),
      MusicTrack(
        id: '4',
        title: 'Cinematic Epic',
        artist: 'Orchestra Studio',
        albumArt: 'https://picsum.photos/200?random=4',
        duration: const Duration(minutes: 5, seconds: 30),
        previewUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
        category: MusicCategory.cinematic,
        downloads: 3200,
        tags: ['cinematic', 'epic', 'orchestra'],
      ),
      MusicTrack(
        id: '5',
        title: 'Hip Hop Beat',
        artist: 'Urban Sounds',
        albumArt: 'https://picsum.photos/200?random=5',
        duration: const Duration(minutes: 3, seconds: 15),
        previewUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
        category: MusicCategory.hiphop,
        downloads: 1800,
        tags: ['hiphop', 'beat', 'urban'],
      ),
      MusicTrack(
        id: '6',
        title: 'Jazz Night',
        artist: 'Smooth Jazz Trio',
        albumArt: 'https://picsum.photos/200?random=6',
        duration: const Duration(minutes: 4, seconds: 45),
        previewUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
        category: MusicCategory.jazz,
        downloads: 670,
        tags: ['jazz', 'smooth', 'night'],
      ),
      MusicTrack(
        id: '7',
        title: 'Pop Summer Hit',
        artist: 'Pop Stars',
        albumArt: 'https://picsum.photos/200?random=7',
        duration: const Duration(minutes: 3, seconds: 30),
        previewUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
        category: MusicCategory.pop,
        downloads: 4500,
        tags: ['pop', 'summer', 'catchy'],
      ),
      MusicTrack(
        id: '8',
        title: 'Rock Anthem',
        artist: 'Rock Legends',
        albumArt: 'https://picsum.photos/200?random=8',
        duration: const Duration(minutes: 4, seconds: 0),
        previewUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
        category: MusicCategory.rock,
        downloads: 2100,
        tags: ['rock', 'anthem', 'guitar'],
      ),
      MusicTrack(
        id: '9',
        title: 'Folk Acoustic',
        artist: 'Acoustic Souls',
        albumArt: 'https://picsum.photos/200?random=9',
        duration: const Duration(minutes: 3, seconds: 50),
        previewUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
        category: MusicCategory.folk,
        downloads: 560,
        tags: ['folk', 'acoustic', 'guitar'],
      ),
      MusicTrack(
        id: '10',
        title: 'Electronic Dreams',
        artist: 'Synth Wave',
        albumArt: 'https://picsum.photos/200?random=10',
        duration: const Duration(minutes: 5, seconds: 10),
        previewUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
        downloadUrl:
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
        category: MusicCategory.electronic,
        downloads: 3400,
        tags: ['electronic', 'synth', 'dance'],
      ),
    ];

    // Filter by query
    var filtered = allTracks;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = allTracks
          .where(
            (t) =>
                t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q) ||
                t.tags.any((tag) => tag.toLowerCase().contains(q)),
          )
          .toList();
    }

    // Filter by category
    if (category != MusicCategory.all) {
      filtered = filtered.where((t) => t.category == category).toList();
    }

    return filtered;
  }

  Future<List<MusicTrack>> _updateMusicDownloadStatus(
    List<MusicTrack> tracks,
  ) async {
    return Future.wait(
      tracks.map((track) async {
        try {
          final isDownloaded = await isMusicDownloaded(track.id);
          final localPath = isDownloaded
              ? await getMusicLocalPath(track.id)
              : null;
          return track.copyWith(
            isDownloaded: isDownloaded,
            localPath: localPath,
          );
        } catch (e) {
          return track;
        }
      }),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MUSIC PLAYBACK
  // ═══════════════════════════════════════════════════════

  Future<void> playPreview(MusicTrack track) async {
    try {
      if (_currentPlayingId == track.id && _audioPlayer.playing) {
        await _audioPlayer.pause();
        return;
      }

      final url = (track.localPath != null && track.localPath!.isNotEmpty)
          ? track.localPath!
          : (track.previewUrl.isNotEmpty
              ? track.previewUrl
              : track.downloadUrl);

      if (url.isEmpty) {
        debugPrint('⚠️ Cannot play preview: audio URL is empty for "${track.title}"');
        return;
      }

      _currentPlayingId = track.id;

      if (!url.startsWith('http')) {
        await _audioPlayer.setFilePath(url);
      } else {
        await _audioPlayer.setUrl(
          url,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          },
        );
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('❌ Play preview error: $e');
    }
  }

  Future<void> pausePreview() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('❌ Pause error: $e');
    }
  }

  Future<void> stopPreview() async {
    try {
      await _audioPlayer.stop();
      _currentPlayingId = null;
    } catch (e) {
      debugPrint('❌ Stop error: $e');
    }
  }

  Future<void> seekPreview(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('❌ Seek error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DOWNLOAD MUSIC
  // ═══════════════════════════════════════════════════════

  Future<MusicTrack?> downloadMusic(
    MusicTrack track, {
    Function(double)? onProgress,
  }) async {
    try {
      final dir = await _getMusicDirectory();
      final fileName = '${track.id}_${_sanitizeName(track.title)}.mp3';
      final filePath = p.join(dir.path, fileName);

      final file = File(filePath);
      if (await file.exists()) {
        return track.copyWith(localPath: filePath, isDownloaded: true);
      }

      final request = http.Request('GET', Uri.parse(track.downloadUrl));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      int received = 0;

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress?.call(received / contentLength);
        }
      }
      await sink.close();

      final updatedTrack = track.copyWith(
        localPath: filePath,
        isDownloaded: true,
      );
      _downloadedTracks[track.id] = updatedTrack;

      return updatedTrack;
    } catch (e) {
      debugPrint('❌ Download music error: $e');
      return null;
    }
  }

  Future<bool> isMusicDownloaded(String trackId) async {
    if (_downloadedTracks.containsKey(trackId)) return true;
    final dir = await _getMusicDirectory();
    final files = await dir.list().toList();
    return files.any((f) => f.path.contains(trackId));
  }

  Future<String?> getMusicLocalPath(String trackId) async {
    if (_downloadedTracks.containsKey(trackId)) {
      return _downloadedTracks[trackId]!.localPath;
    }
    final dir = await _getMusicDirectory();
    final files = await dir.list().toList();
    for (final file in files) {
      if (file.path.contains(trackId)) return file.path;
    }
    return null;
  }

  Future<List<MusicTrack>> getDownloadedMusic() async {
    final tracks = <MusicTrack>[];
    try {
      final dir = await _getMusicDirectory();
      if (!await dir.exists()) return tracks;

      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.mp3')) {
          final name = p.basenameWithoutExtension(file.path);
          final parts = name.split('_');
          if (parts.isNotEmpty) {
            tracks.add(
              MusicTrack(
                id: parts[0],
                title: parts.length > 1
                    ? parts.sublist(1).join('_')
                    : 'Downloaded',
                artist: 'Downloaded',
                duration: Duration.zero,
                previewUrl: file.path,
                downloadUrl: file.path,
                localPath: file.path,
                isDownloaded: true,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Get downloaded music error: $e');
    }
    return tracks;
  }

  Future<bool> deleteMusicDownload(String trackId) async {
    try {
      final localPath = await getMusicLocalPath(trackId);
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
          _downloadedTracks.remove(trackId);
          return true;
        }
      }
    } catch (e) {
      debugPrint('❌ Delete music error: $e');
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DOWNLOAD IMAGE
  // ═══════════════════════════════════════════════════════

  Future<StockImage?> downloadImage(
    StockImage image, {
    Function(double)? onProgress,
  }) async {
    try {
      final dir = await _getImagesDirectory();
      final fileName = '${image.id}.jpg';
      final filePath = p.join(dir.path, fileName);

      final file = File(filePath);
      if (await file.exists()) {
        return image.copyWith(localPath: filePath, isDownloaded: true);
      }

      final request = http.Request('GET', Uri.parse(image.fullUrl));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      int received = 0;

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress?.call(received / contentLength);
        }
      }
      await sink.close();

      final updatedImage = image.copyWith(
        localPath: filePath,
        isDownloaded: true,
      );
      _downloadedImages[image.id] = updatedImage;

      return updatedImage;
    } catch (e) {
      debugPrint('❌ Download image error: $e');
      return null;
    }
  }

  Future<bool> isImageDownloaded(String imageId) async {
    if (_downloadedImages.containsKey(imageId)) return true;
    final dir = await _getImagesDirectory();
    final file = File(p.join(dir.path, '$imageId.jpg'));
    return file.exists();
  }

  Future<String?> getImageLocalPath(String imageId) async {
    if (_downloadedImages.containsKey(imageId)) {
      return _downloadedImages[imageId]!.localPath;
    }
    final dir = await _getImagesDirectory();
    final file = File(p.join(dir.path, '$imageId.jpg'));
    if (await file.exists()) return file.path;
    return null;
  }

  Future<List<StockImage>> getDownloadedImages() async {
    final images = <StockImage>[];
    try {
      final dir = await _getImagesDirectory();
      if (!await dir.exists()) return images;

      await for (final file in dir.list()) {
        if (file is File &&
            (file.path.endsWith('.jpg') || file.path.endsWith('.png'))) {
          final id = p.basenameWithoutExtension(file.path);
          images.add(
            StockImage(
              id: id,
              title: 'Downloaded Image',
              photographer: 'Local',
              thumbnailUrl: file.path,
              previewUrl: file.path,
              fullUrl: file.path,
              localPath: file.path,
              width: 1920,
              height: 1080,
              isDownloaded: true,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Get downloaded images error: $e');
    }
    return images;
  }

  Future<bool> deleteImageDownload(String imageId) async {
    try {
      final dir = await _getImagesDirectory();
      final file = File(p.join(dir.path, '$imageId.jpg'));
      if (await file.exists()) {
        await file.delete();
        _downloadedImages.remove(imageId);
        return true;
      }
    } catch (e) {
      debugPrint('❌ Delete image error: $e');
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  Future<Directory> _getMusicDirectory() async {
    final appDir = await getExternalStorageDirectory();
    final musicDir = Directory(p.join(appDir!.path, 'music'));
    if (!await musicDir.exists()) {
      await musicDir.create(recursive: true);
    }
    return musicDir;
  }

  Future<Directory> _getImagesDirectory() async {
    final appDir = await getExternalStorageDirectory();
    final imagesDir = Directory(p.join(appDir!.path, 'stock_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  String _sanitizeName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();
  }

  // ═══════════════════════════════════════════════════════
  // ✅ FETCH PIXABAY STOCK VIDEOS
  // ═══════════════════════════════════════════════════════

  static const String _videoBaseUrl = 'https://pixabay.com/api/videos/';

  /// True when the last [fetchVideos] fell back to the local sample list
  /// (missing API key, network error, or non-200 response) so UIs can tell
  /// real Pixabay results from placeholders.
  bool lastVideoFetchUsedFallback = false;

  Future<List<StockVideo>> fetchVideos({
    String query = '',
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      if (!Api.isConfigured || Api.pixaBayKey.isEmpty) {
        debugPrint('⚠️ Pixabay key missing; returning development stock videos');
        lastVideoFetchUsedFallback = true;
        return _getMockStockVideos(query);
      }

      final params = {
        'key': Api.pixaBayKey,
        'q': query.isNotEmpty ? query : 'nature',
        'page': page.toString(),
        'per_page': perPage.toString(),
        'safesearch': 'true',
      };

      final uri = Uri.parse(_videoBaseUrl).replace(queryParameters: params);
      debugPrint('📹 Fetching Pixabay videos: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hits = data['hits'] as List? ?? [];

        final videos = hits
            .map((hit) {
              try {
                return StockVideo.fromPixabay(hit);
              } catch (e) {
                debugPrint('❌ Parse stock video error: $e');
                return null;
              }
            })
            .whereType<StockVideo>()
            .toList();

        if (videos.isEmpty) {
          lastVideoFetchUsedFallback = true;
          return _getMockStockVideos(query);
        }
        lastVideoFetchUsedFallback = false;
        return await _updateVideosDownloadStatus(videos);
      } else {
        debugPrint('❌ Pixabay Video API error: ${response.statusCode}');
        lastVideoFetchUsedFallback = true;
        return _getMockStockVideos(query);
      }
    } catch (e) {
      debugPrint('❌ Fetch videos error: $e');
      lastVideoFetchUsedFallback = true;
      return _getMockStockVideos(query);
    }
  }

  List<StockVideo> _getMockStockVideos(String query) {
    final sampleVideos = [
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    ];

    return List.generate(4, (index) {
      final id = 'pixabay_vid_${index + 1}';
      return StockVideo(
        id: id,
        title: 'Pixabay Video Asset ${index + 1}',
        author: 'Pixabay Creator ${index + 1}',
        videoUrl: sampleVideos[index % sampleVideos.length],
        thumbnailUrl: 'https://picsum.photos/640/360?random=${index + 50}',
        duration: const Duration(seconds: 15),
        width: 1920,
        height: 1080,
        tags: ['stock', 'video', query.isNotEmpty ? query : 'nature'],
      );
    });
  }

  Future<List<StockVideo>> _updateVideosDownloadStatus(
    List<StockVideo> videos,
  ) async {
    return Future.wait(
      videos.map((vid) async {
        try {
          final isDownloaded = await isVideoDownloaded(vid.id);
          final localPath = isDownloaded
              ? await getVideoLocalPath(vid.id)
              : null;
          return vid.copyWith(isDownloaded: isDownloaded, localPath: localPath);
        } catch (e) {
          return vid;
        }
      }),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DOWNLOAD PIXABAY VIDEO ASSET
  // ═══════════════════════════════════════════════════════

  Future<StockVideo?> downloadVideoAsset(
    StockVideo video, {
    Function(double)? onProgress,
  }) async {
    File? partFile;
    try {
      final dir = await _getVideosDirectory();
      final fileName = 'pixabay_vid_${video.id}.mp4';
      final filePath = p.join(dir.path, fileName);

      final file = File(filePath);
      if (await file.exists()) {
        return video.copyWith(localPath: filePath, isDownloaded: true);
      }

      // Write to "<name>.part" and only rename after a verified, complete
      // transfer. Previously a dropped connection left a truncated file at
      // the final path, which then poisoned exports with
      // "could not find codec parameters".
      partFile = File('$filePath.part');

      final request = http.Request('GET', Uri.parse(video.videoUrl));
      final response =
          await http.Client().send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        debugPrint(
          '❌ Download video asset: HTTP ${response.statusCode} for "${video.videoUrl}"',
        );
        return null;
      }

      final contentLength = response.contentLength ?? 0;
      int received = 0;

      final sink = partFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (contentLength > 0) {
            onProgress?.call(received / contentLength);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      // Truncated / empty transfer guard (contentLength unknown => require
      // at least a small header-sized payload).
      if (received == 0 ||
          (contentLength > 0 && received < contentLength)) {
        debugPrint(
          '❌ Download video asset incomplete: $received / $contentLength bytes',
        );
        await partFile.delete();
        return null;
      }

      await partFile.rename(filePath);
      partFile = null;

      final updated = video.copyWith(localPath: filePath, isDownloaded: true);
      return updated;
    } catch (e) {
      debugPrint('❌ Download video asset error: $e');
      try {
        await partFile?.delete();
      } catch (_) {}
      return null;
    }
  }

  /// Files smaller than this cannot be playable video content (truncated
  /// transfer or an HTML error page saved as .mp4).
  static const int _minValidVideoBytes = 10 * 1024;

  Future<bool> isVideoDownloaded(String videoId) async {
    final localPath = await getVideoLocalPath(videoId);
    return localPath != null;
  }

  /// Returns the cached path only when the file looks like a complete video.
  /// Invalid leftovers (from the pre-verified downloader era) are deleted so
  /// the asset re-downloads cleanly instead of poisoning exports.
  Future<String?> getVideoLocalPath(String videoId) async {
    final dir = await _getVideosDirectory();
    final path = p.join(dir.path, 'pixabay_vid_$videoId.mp4');
    final f = File(path);
    if (!await f.exists()) return null;

    final length = await f.length();
    if (length < _minValidVideoBytes) {
      debugPrint(
        '🗑️ Removing invalid cached stock video ($length B): $path',
      );
      try {
        await f.delete();
      } catch (_) {}
      return null;
    }
    return path;
  }

  Future<Directory> _getVideosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'pixabay_videos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // One-time hygiene: legacy sample-video downloads were saved under the
    // doubled prefix "pixabay_vid_pixabay_vid_N.mp4" and some are truncated
    // (they broke exports with "could not find codec parameters"). They are
    // freely re-downloadable, so drop them on sight.
    try {
      final legacy = RegExp(r'pixabay_vid_pixabay_vid_\d+\.mp4$');
      await for (final e in dir.list()) {
        if (e is File && legacy.hasMatch(e.path)) {
          debugPrint('🗑️ Removing legacy stock sample: ${p.basename(e.path)}');
          await e.delete();
        }
      }
    } catch (_) {}

    return dir;
  }

  void dispose() {
    try {
      _audioPlayer.dispose();
    } catch (e) {
      debugPrint('❌ Dispose error: $e');
    }
  }
}
