import 'dart:async';
import 'package:flutter/material.dart';
import '../models/epub_book.dart';
import '../../speaker_player/tts_controller.dart';

/// MINIMAL audiobook controller - NO caching, NO background generation
class SimpleAudiobookController {
  final EpubBook book;
  final String bookId;
  final Future<String?> Function(int chapterIndex) getChapterText;

  bool _isPlaying = false;
  bool _stopRequested = false;
  int _currentChapter = 0;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  String _status = 'Idle';
  String get status => _status;

  int get currentChapter => _currentChapter;
  int get totalChapters => book.chapterCount;

  SimpleAudiobookController({
    required this.book,
    required this.bookId,
    required this.getChapterText,
  });

  Future<void> start(BuildContext context, {int fromChapter = 0}) async {
    if (_isPlaying) return;

    _isPlaying = true;
    _stopRequested = false;
    _currentChapter = fromChapter;

    debugPrint('[SimpleAudiobook] Starting from chapter $_currentChapter');

    while (!_stopRequested && _currentChapter < book.chapterCount) {
      try {
        _updateStatus(
          'Playing Chapter ${_currentChapter + 1}/${book.chapterCount}',
        );

        // Get text
        final text = await getChapterText(_currentChapter);
        if (text == null || text.isEmpty) {
          debugPrint('[SimpleAudiobook] Empty chapter, skipping');
          _currentChapter++;
          continue;
        }

        debugPrint('[SimpleAudiobook] Speaking chapter $_currentChapter...');

        // Wait for completion
        final completer = Completer<bool>();

        // Speak with TtsController
        final success = await TtsController.instance.speak(
          text: text,
          context: context,
          showUi: true,
          useCache: false, // ❌ DISABLE caching for now
          onCompleted: () {
            debugPrint('[SimpleAudiobook] Chapter $_currentChapter completed');
            if (!completer.isCompleted) completer.complete(true);
          },
          onError: (error) {
            debugPrint('[SimpleAudiobook] Error: $error');
            if (!completer.isCompleted) completer.complete(false);
          },
        );

        if (!success) {
          debugPrint('[SimpleAudiobook] Speak failed');
          _updateStatus('❌ Chapter ${_currentChapter + 1} failed');

          // Show error and WAIT for user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Chapter ${_currentChapter + 1} failed. Press Next to continue.',
              ),
              duration: Duration(days: 1), // Wait for user
            ),
          );

          break; // STOP on failure
        }

        // Wait for completion callback
        await completer.future.timeout(
          Duration(minutes: 10),
          onTimeout: () {
            debugPrint('[SimpleAudiobook] Timeout');
            return false;
          },
        );

        if (_stopRequested) break;

        // Move to next chapter
        _currentChapter++;

        // Small delay
        await Future.delayed(Duration(seconds: 1));
      } catch (e) {
        debugPrint('[SimpleAudiobook] Error: $e');
        _updateStatus('❌ Error: $e');
        break;
      }
    }

    _isPlaying = false;
    _updateStatus('Stopped');
    debugPrint('[SimpleAudiobook] Finished');
  }

  void stop(BuildContext context) {
    _stopRequested = true;
    _isPlaying = false;
    TtsController.instance.forceStop();
    _updateStatus('Stopped');
  }

  void pause() {
    TtsController.instance.pause();
    _updateStatus('Paused');
  }

  void resume() {
    TtsController.instance.play();
    _updateStatus('Playing');
  }

  void _updateStatus(String newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    _statusController.close();
  }
}
