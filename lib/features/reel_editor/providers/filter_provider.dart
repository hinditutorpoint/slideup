import 'package:flutter_riverpod/legacy.dart';
import '../core/validation/numeric_guard.dart';

class ReelFilter {
  final String id;
  final String name;
  final String ffmpeg; // e.g. 'eq=contrast=1.2' or 'lut3d=file'
  const ReelFilter({required this.id, required this.name, required this.ffmpeg});
  static const all = [
    ReelFilter(id: 'none', name: 'None', ffmpeg: ''),
    ReelFilter(id: 'vivid', name: 'Vivid', ffmpeg: 'eq=contrast=1.15:saturation=1.25'),
    ReelFilter(id: 'bw', name: 'B&W', ffmpeg: 'hue=s=0'),
    ReelFilter(id: 'warm', name: 'Warm', ffmpeg: 'colorbalance=rs=0.2:gs=0:bs=-0.2'),
    ReelFilter(id: 'cool', name: 'Cool', ffmpeg: 'colorbalance=rs=-0.15:bs=0.15'),
    ReelFilter(id: 'bright', name: 'Bright', ffmpeg: 'eq=brightness=0.08:contrast=1.05'),
  ];
  static ReelFilter byId(String id) => all.firstWhere((e) => e.id == id, orElse: () => all.first);
}

class FilterNotifier extends StateNotifier<ReelFilter> {
  FilterNotifier() : super(ReelFilter.all.first);
  void select(String id) {
    final f = ReelFilter.byId(id);
    state = f;
  }

  void setIntensity(double intensity) {
    // intensity 0-1 guarded, stored via ReelProject.filterSettings on project
    intensity = NumericGuard.sanitizeOpacity(intensity);
    // no-op here — project owns intensity, this just validates
  }
}

final filterProvider = StateNotifierProvider<FilterNotifier, ReelFilter>((ref) => FilterNotifier());
