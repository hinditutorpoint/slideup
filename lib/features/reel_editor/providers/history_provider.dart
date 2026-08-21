import 'package:flutter_riverpod/legacy.dart';
import '../models/reel_project.dart';

/// History manager md:16 — undo/redo with grouped transactions, memory-conscious (max 50)
class HistoryState {
  final List<ReelProject> undoStack;
  final List<ReelProject> redoStack;
  const HistoryState({this.undoStack = const [], this.redoStack = const []});
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;
  HistoryState copyWith({List<ReelProject>? undoStack, List<ReelProject>? redoStack}) =>
      HistoryState(undoStack: undoStack ?? this.undoStack, redoStack: redoStack ?? this.redoStack);
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  static const int _maxDepth = 50;
  // creative: coalesce rapid pushes (drag) into one entry md:507
  DateTime? _lastPush;
  String? _lastId;
  HistoryNotifier() : super(const HistoryState());

  void push(ReelProject before, {String? coalesceId}) {
    final now = DateTime.now();
    final isCoalesce = coalesceId != null && _lastId == coalesceId && _lastPush != null && now.difference(_lastPush!).inMilliseconds < 350;
    if (isCoalesce) {
      // replace top instead of pushing new — keeps drag as 1 entry
      _lastPush = now;
      return;
    }
    final list = [...state.undoStack, before];
    if (list.length > _maxDepth) list.removeAt(0);
    state = HistoryState(undoStack: list, redoStack: []);
    _lastPush = now;
    _lastId = coalesceId;
  }

  void beginTransaction() { _lastPush = null; _lastId = null; }
  void commitTransaction(ReelProject before) => push(before);

  ReelProject? undo(ReelProject current) {
    if (!state.canUndo) return null;
    final prev = state.undoStack.last;
    final newUndo = [...state.undoStack]..removeLast();
    final newRedo = [...state.redoStack, current];
    state = HistoryState(undoStack: newUndo, redoStack: newRedo);
    return prev;
  }

  ReelProject? redo(ReelProject current) {
    if (!state.canRedo) return null;
    final next = state.redoStack.last;
    final newRedo = [...state.redoStack]..removeLast();
    final newUndo = [...state.undoStack, current];
    if (newUndo.length > _maxDepth) newUndo.removeAt(0);
    state = HistoryState(undoStack: newUndo, redoStack: newRedo);
    return next;
  }

  void clear() => state = const HistoryState();
}

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) => HistoryNotifier());
