import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Available themes
enum AppThemeMode {
  dark('Dark', Icons.dark_mode),
  light('Light', Icons.light_mode),
  indigo('Indigo', Icons.color_lens),
  teal('Teal', Icons.spa),
  gold('Gold', Icons.star),
  yellow('Yellow', Icons.wb_sunny),
  purple('Purple', Icons.auto_awesome),
  green('Green', Icons.eco),
  red('Red', Icons.favorite),
  blue('Blue', Icons.water_drop),
  system('System', Icons.settings_suggest);

  final String label;
  final IconData icon;
  const AppThemeMode(this.label, this.icon);
}

// Theme state
class ThemeState {
  final AppThemeMode themeMode;
  final bool useSystemTheme;
  final bool useDynamicColors;

  const ThemeState({
    this.themeMode = AppThemeMode.dark,
    this.useSystemTheme = false,
    this.useDynamicColors = false,
  });

  ThemeState copyWith({
    AppThemeMode? themeMode,
    bool? useSystemTheme,
    bool? useDynamicColors,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      useSystemTheme: useSystemTheme ?? this.useSystemTheme,
      useDynamicColors: useDynamicColors ?? this.useDynamicColors,
    );
  }
}

// Theme notifier (Hive)
class ThemeNotifier extends AsyncNotifier<ThemeState> {
  static const _boxName = 'settingsBox';

  static const String _themeKey = 'app_theme';
  static const String _systemThemeKey = 'use_system_theme';
  static const String _dynamicColorsKey = 'use_dynamic_colors';

  Box get _box => Hive.box(_boxName);

  @override
  Future<ThemeState> build() async {
    try {
      debugPrint('🎨 Loading theme from Hive...');
      final theme = _loadTheme();
      debugPrint(
        '🎨 Theme loaded: ${theme.themeMode.name}, system=${theme.useSystemTheme}',
      );
      return theme;
    } catch (e, stack) {
      debugPrint('⚠️ Theme load error: $e\n$stack');
      return const ThemeState();
    }
  }

  ThemeState _loadTheme() {
    try {
      final themeIndex = _box.get(_themeKey, defaultValue: 0) as int;

      final useSystem = _box.get(_systemThemeKey, defaultValue: false) as bool;

      final useDynamic =
          _box.get(_dynamicColorsKey, defaultValue: false) as bool;

      return ThemeState(
        themeMode: AppThemeMode
            .values[themeIndex.clamp(0, AppThemeMode.values.length - 1)],
        useSystemTheme: useSystem,
        useDynamicColors: useDynamic,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to parse theme from Hive: $e');
      return const ThemeState();
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = AsyncData(
      state.value!.copyWith(themeMode: mode, useSystemTheme: false),
    );

    await _box.put(_themeKey, mode.index);
    await _box.put(_systemThemeKey, false);
  }

  Future<void> setUseSystemTheme(bool value) async {
    state = AsyncData(state.value!.copyWith(useSystemTheme: value));
    await _box.put(_systemThemeKey, value);
  }

  Future<void> setUseDynamicColors(bool value) async {
    state = AsyncData(state.value!.copyWith(useDynamicColors: value));
    await _box.put(_dynamicColorsKey, value);
  }

  void toggleTheme() {
    final currentIndex = state.value!.themeMode.index;
    final nextIndex = (currentIndex + 1) % (AppThemeMode.values.length - 1);

    setTheme(AppThemeMode.values[nextIndex]);
  }
}

// Provider
final themeProvider = AsyncNotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);
