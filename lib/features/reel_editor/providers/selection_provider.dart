import 'package:flutter_riverpod/legacy.dart';

/// Unified selection for right-side properties panel — each object type has own panel
enum ReelSelectionType { none, clip, text, sticker, overlay, audio, shape }

class ReelSelection {
  final String? id;
  final ReelSelectionType type;
  const ReelSelection({this.id, this.type = ReelSelectionType.none});
  bool get isNone => type == ReelSelectionType.none || id == null;
  ReelSelection copyWith({String? id, ReelSelectionType? type, bool clear = false}) =>
      clear ? const ReelSelection() : ReelSelection(id: id ?? this.id, type: type ?? this.type);
}

class SelectionNotifier extends StateNotifier<ReelSelection> {
  SelectionNotifier() : super(const ReelSelection());
  void select(String id, ReelSelectionType type) => state = ReelSelection(id: id, type: type);
  void clear() => state = const ReelSelection();
}

final selectionProvider = StateNotifierProvider<SelectionNotifier, ReelSelection>((ref) => SelectionNotifier());
