import 'package:flutter_riverpod/flutter_riverpod.dart';

class IntentState {
  final String? openedFilePath;
  final bool isHandling;

  const IntentState({this.openedFilePath, this.isHandling = false});

  IntentState copyWith({String? openedFilePath, bool? isHandling}) {
    return IntentState(
      openedFilePath: openedFilePath ?? this.openedFilePath,
      isHandling: isHandling ?? this.isHandling,
    );
  }
}

class IntentNotifier extends Notifier<IntentState> {
  @override
  IntentState build() {
    return const IntentState();
  }

  void setOpenedFile(String? path) {
    state = state.copyWith(openedFilePath: path);
  }

  void setHandling(bool isHandling) {
    state = state.copyWith(isHandling: isHandling);
  }

  void clear() {
    state = const IntentState();
  }
}

final intentProvider = NotifierProvider<IntentNotifier, IntentState>(
  () => IntentNotifier(),
);
