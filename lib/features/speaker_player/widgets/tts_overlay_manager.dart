import 'package:flutter/material.dart';
import 'floating_audio_player.dart';
import '../tts_controller.dart';

class TtsOverlayManager {
  static OverlayEntry? _overlayEntry;
  static GlobalKey<FloatingAudioPlayerState>? _playerKey;

  static void show(BuildContext context, {String? text, String? modelName}) {
    hide();

    _playerKey = GlobalKey<FloatingAudioPlayerState>();

    _overlayEntry = OverlayEntry(
      builder: (context) => FloatingAudioPlayer(
        key: _playerKey,
        text: text,
        modelName: modelName,
        onClose: () {
          TtsController.instance.stop(context);
          hide();
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void forceHide() {
    try {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } catch (e) {
      debugPrint('[TtsOverlayManager] Force hide error: $e');
    }
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _playerKey = null;
  }

  static void updateText(String? text) {
    _playerKey?.currentState?.updateText(text);
  }

  static void updateModelName(String? modelName) {
    _playerKey?.currentState?.updateModelName(modelName);
  }

  static bool get isShowing => _overlayEntry != null;
}
