import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reel_project.dart';
import '../persistence/reel_project_repository.dart';

/// Autosave md:516-526 debounced, non-blocking, crash-safe
final reelProjectRepositoryProvider = Provider<ReelProjectRepository>((ref) => ReelProjectRepository());

final autosaveProvider = Provider<AutosaveController>((ref) {
  final repo = ref.watch(reelProjectRepositoryProvider);
  final c = AutosaveController(repo);
  ref.onDispose(c.dispose);
  return c;
});

class AutosaveController with WidgetsBindingObserver {
  final ReelProjectRepository repo;
  Timer? _debounce;
  ReelProject? _pending;
  AutosaveController(this.repo) { WidgetsBinding.instance.addObserver(this); }

  void schedule(ReelProject p) {
    _pending = p;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      final proj = _pending;
      if (proj == null) return;
      try {
        await repo.autosave(proj);
      } catch (_) {}
    });
  }

  // creative: flush on lifecycle pause — crash recovery md:540
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _pending != null) {
      _debounce?.cancel();
      repo.autosave(_pending!);
    }
  }

  Future<void> flush() async { _debounce?.cancel(); if (_pending!=null) await repo.autosave(_pending!); }

  void dispose() { _debounce?.cancel(); WidgetsBinding.instance.removeObserver(this); }
}
