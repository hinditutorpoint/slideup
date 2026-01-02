import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_service.dart';

final audioHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  throw UnimplementedError('AudioHandler must be initialized in main()');
});
