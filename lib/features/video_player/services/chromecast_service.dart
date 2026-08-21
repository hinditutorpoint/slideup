import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

/// Chromecast device representation
class ChromecastDevice {
  final String id;
  final String name;
  final String? modelName;
  final bool isConnected;

  const ChromecastDevice({
    required this.id,
    required this.name,
    this.modelName,
    this.isConnected = false,
  });

  ChromecastDevice copyWith({
    String? id,
    String? name,
    String? modelName,
    bool? isConnected,
  }) {
    return ChromecastDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      modelName: modelName ?? this.modelName,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

enum CastState { idle, connecting, connected, disconnecting }

/// Chromecast Service
///
/// Real implementation backed by the official Google Cast SDK through the
/// `flutter_chrome_cast` plugin (native Android + iOS):
/// - Discovery via the native Cast framework (mDNS)
/// - Session management with automatic reconnection
/// - Media playback through the Default Media Receiver app
class ChromecastService {
  static final ChromecastService _instance = ChromecastService._internal();
  factory ChromecastService() => _instance;
  ChromecastService._internal();

  static const Duration _connectTimeout = Duration(seconds: 20);

  final _stateController = StreamController<CastState>.broadcast();
  Stream<CastState> get stateStream => _stateController.stream;

  final _devicesController =
      StreamController<List<ChromecastDevice>>.broadcast();
  Stream<List<ChromecastDevice>> get devicesStream => _devicesController.stream;

  CastState _state = CastState.idle;
  CastState get state => _state;

  List<ChromecastDevice> _devices = [];
  List<ChromecastDevice> get devices => _devices;

  ChromecastDevice? _connectedDevice;
  ChromecastDevice? get connectedDevice => _connectedDevice;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _initialized = false;
  StreamSubscription<List<GoogleCastDevice>>? _discoverySub;
  bool _isDisposed = false;

  // ═══════════════════════════════════════════════════════
  // ✅ INITIALIZATION
  // ═══════════════════════════════════════════════════════

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'Google Cast is only supported on Android and iOS',
      );
    }

    const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    final GoogleCastOptions options;
    if (Platform.isIOS) {
      options = IOSGoogleCastOptions(
        GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
        stopCastingOnAppTerminated: true,
      );
    } else {
      options = GoogleCastOptionsAndroid(
        appId: appId,
        stopCastingOnAppTerminated: true,
      );
    }

    await GoogleCastContext.instance.setSharedInstanceWithOptions(options);
    _initialized = true;
    debugPrint('✅ Google Cast context initialized');
  }

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  // ═══════════════════════════════════════════════════════
  // ✅ DEVICE DISCOVERY
  // ═══════════════════════════════════════════════════════

  Future<void> startDiscovery() async {
    if (_isDisposed) return;

    try {
      await _ensureInitialized();

      await _discoverySub?.cancel();
      _devices = [];
      _isScanning = true;
      _emitDevices();

      debugPrint('🔍 Starting Chromecast discovery...');

      _discoverySub =
          GoogleCastDiscoveryManager.instance.devicesStream.listen((found) {
        if (_isDisposed) return;
        _devices = found
            .map(
              (d) => ChromecastDevice(
                id: d.uniqueID.isNotEmpty ? d.uniqueID : d.deviceID,
                name: d.friendlyName,
                modelName: d.modelName,
              ),
            )
            .toList();
        debugPrint('📡 Discovered ${_devices.length} cast device(s)');
        _emitDevices();
      });

      await GoogleCastDiscoveryManager.instance.startDiscovery();
    } catch (e) {
      debugPrint('❌ Discovery error: $e');
      if (!_isDisposed) {
        _isScanning = false;
        _emitDevices();
      }
    }
  }

  Future<void> stopDiscovery() async {
    _discoverySub?.cancel();
    _discoverySub = null;
    _isScanning = false;
    if (!_isDisposed) _emitDevices();

    try {
      if (_initialized) {
        await GoogleCastDiscoveryManager.instance.stopDiscovery();
      }
    } catch (e) {
      debugPrint('❌ Stop discovery error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ CONNECTION
  // ═══════════════════════════════════════════════════════

  Future<bool> connect(ChromecastDevice device) async {
    if (_isDisposed) return false;

    try {
      await _ensureInitialized();
      _updateState(CastState.connecting);
      debugPrint('🔗 Connecting to ${device.name}...');

      final started = await GoogleCastSessionManager.instance
          .startSessionWithDevice(
        GoogleCastDevice(
          deviceID: device.id,
          friendlyName: device.name,
          modelName: device.modelName,
          statusText: null,
          deviceVersion: '',
          isOnLocalNetwork: true,
          category: 'ab5f194b-aba3-4931-956c-63e60a8b3d27',
          uniqueID: device.id,
        ),
      );

      if (!started) {
        throw Exception('Could not start cast session');
      }

      // Wait until the native session reports a connected state
      final deadline = DateTime.now().add(_connectTimeout);
      while (DateTime.now().isBefore(deadline)) {
        if (_isDisposed) return false;
        final connectionState =
            GoogleCastSessionManager.instance.connectionState;
        if (connectionState == GoogleCastConnectState.connected) break;
        if (connectionState == GoogleCastConnectState.disconnected &&
            DateTime.now()
                .isAfter(deadline.subtract(_connectTimeout ~/ 2))) {
          throw Exception('Cast session disconnected while connecting');
        }
        await Future.delayed(const Duration(milliseconds: 250));
      }

      if (GoogleCastSessionManager.instance.connectionState !=
          GoogleCastConnectState.connected) {
        throw Exception('Timed out connecting to ${device.name}');
      }

      _connectedDevice = device.copyWith(isConnected: true);
      _updateState(CastState.connected);
      debugPrint('✅ Connected to ${device.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      if (!_isDisposed) _updateState(CastState.idle);
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice == null && _state == CastState.idle) return;

    try {
      _updateState(CastState.disconnecting);
      debugPrint('🔌 Disconnecting from cast session...');
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
      debugPrint('✅ Disconnected');
    } catch (e) {
      debugPrint('❌ Disconnect error: $e');
    } finally {
      if (!_isDisposed) _updateState(CastState.idle);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MEDIA CONTROL
  // ═══════════════════════════════════════════════════════

  Future<bool> loadMedia({
    required String url,
    String? title,
    String? thumbnailUrl,
    Duration? startPosition,
  }) async {
    if (_state != CastState.connected) {
      debugPrint('⚠️ Not connected to any device');
      return false;
    }

    try {
      debugPrint('📺 Loading media on cast device: $url');

      await GoogleCastRemoteMediaClient.instance.loadMedia(
        GoogleCastMediaInformation(
          contentId: url,
          streamType: CastMediaStreamType.buffered,
          contentType: _contentTypeFor(url),
          contentUrl: Uri.parse(url),
          metadata: GoogleCastGenericMediaMetadata(
            title: title,
            images: thumbnailUrl != null
                ? [GoogleCastImage(url: Uri.parse(thumbnailUrl))]
                : null,
          ),
        ),
        autoPlay: true,
        playPosition: startPosition ?? Duration.zero,
      );

      debugPrint('✅ Media loaded');
      return true;
    } catch (e) {
      debugPrint('❌ Load media error: $e');
      return false;
    }
  }

  Future<void> play() async {
    if (_state != CastState.connected) return;

    try {
      debugPrint('▶️ Cast: Play');
      await GoogleCastRemoteMediaClient.instance.play();
    } catch (e) {
      debugPrint('❌ Cast play error: $e');
    }
  }

  Future<void> pause() async {
    if (_state != CastState.connected) return;

    try {
      debugPrint('⏸️ Cast: Pause');
      await GoogleCastRemoteMediaClient.instance.pause();
    } catch (e) {
      debugPrint('❌ Cast pause error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    if (_state != CastState.connected) return;

    try {
      debugPrint('⏩ Cast: Seek to ${position.inSeconds}s');
      await GoogleCastRemoteMediaClient.instance.seek(
        GoogleCastMediaSeekOption(position: position),
      );
    } catch (e) {
      debugPrint('❌ Cast seek error: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    if (_state != CastState.connected) return;

    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      debugPrint('🔊 Cast: Volume ${(clampedVolume * 100).toInt()}%');
      GoogleCastSessionManager.instance.setDeviceVolume(clampedVolume);
    } catch (e) {
      debugPrint('❌ Cast volume error: $e');
    }
  }

  Future<void> stop() async {
    if (_state != CastState.connected) return;

    try {
      debugPrint('⏹️ Cast: Stop');
      await GoogleCastRemoteMediaClient.instance.stop();
    } catch (e) {
      debugPrint('❌ Cast stop error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPERS
  // ═══════════════════════════════════════════════════════

  String _contentTypeFor(String url) {
    final path = url.toLowerCase().split('?').first;
    if (path.endsWith('.m3u8')) return 'application/x-mpegurl';
    if (path.endsWith('.mpd')) return 'application/dash+xml';
    if (path.endsWith('.mkv')) return 'video/x-matroska';
    if (path.endsWith('.webm')) return 'video/webm';
    if (path.endsWith('.mov')) return 'video/quicktime';
    if (path.endsWith('.avi')) return 'video/x-msvideo';
    if (path.endsWith('.mp3')) return 'audio/mp3';
    if (path.endsWith('.flac')) return 'audio/flac';
    if (path.endsWith('.wav')) return 'audio/wav';
    if (path.endsWith('.m4a') || path.endsWith('.aac')) return 'audio/mp4';
    return 'video/mp4';
  }

  void _updateState(CastState newState) {
    if (_isDisposed) return;
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  void _emitDevices() {
    if (!_devicesController.isClosed) {
      _devicesController.add(List.unmodifiable(_devices));
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DISPOSE
  // ═══════════════════════════════════════════════════════

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    stopDiscovery();

    if (!_stateController.isClosed) {
      _stateController.close();
    }
    if (!_devicesController.isClosed) {
      _devicesController.close();
    }
  }
}
