import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/theme_provider.dart';

class AppTheme {
  // ==================== DARK THEME ====================
  static const Color _darkPrimary = Color(0xFF6C63FF);
  static const Color _darkSecondary = Color(0xFF00D9FF);
  static const Color _darkBackground = Color(0xFF1A1A2E);
  static const Color _darkSurface = Color(0xFF16213E);
  static const Color _darkCard = Color(0xFF0F3460);

  // ==================== LIGHT THEME ====================
  static const Color _lightPrimary = Color(0xFF5B4FCF);
  static const Color _lightSecondary = Color(0xFF00B4D8);
  static const Color _lightBackground = Color(0xFFF8F9FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightCard = Color(0xFFFFFFFF);

  // ==================== INDIGO THEME ====================
  static const Color _indigoPrimary = Color(0xFF3F51B5);
  static const Color _indigoSecondary = Color(0xFF7986CB);
  static const Color _indigoBackground = Color(0xFF0D1B2A);
  static const Color _indigoSurface = Color(0xFF1B263B);
  static const Color _indigoCard = Color(0xFF273549);

  // ==================== TEAL THEME ====================
  static const Color _tealPrimary = Color(0xFF00BFA5);
  static const Color _tealSecondary = Color(0xFF64FFDA);
  static const Color _tealBackground = Color(0xFF0A1929);
  static const Color _tealSurface = Color(0xFF132F4C);
  static const Color _tealCard = Color(0xFF173A5E);

  // ==================== GOLD THEME ====================
  static const Color _goldPrimary = Color(0xFFFFB300);
  static const Color _goldSecondary = Color(0xFFFFD54F);
  static const Color _goldBackground = Color(0xFF1C1C1C);
  static const Color _goldSurface = Color(0xFF2D2D2D);
  static const Color _goldCard = Color(0xFF3D3D3D);

  // ==================== YELLOW THEME ====================
  static const Color _yellowPrimary = Color(0xFFFFC107);
  static const Color _yellowSecondary = Color(0xFFFFEB3B);
  static const Color _yellowBackground = Color(0xFFFFFDF7);
  static const Color _yellowSurface = Color(0xFFFFFFFF);
  static const Color _yellowCard = Color(0xFFFFF8E1);

  // ==================== PURPLE THEME ====================
  static const Color _purplePrimary = Color(0xFF9C27B0);
  static const Color _purpleSecondary = Color(0xFFE040FB);
  static const Color _purpleBackground = Color(0xFF12002B);
  static const Color _purpleSurface = Color(0xFF1E0336);
  static const Color _purpleCard = Color(0xFF2A0845);

  // ==================== GREEN THEME ====================
  static const Color _greenPrimary = Color(0xFF4CAF50);
  static const Color _greenSecondary = Color(0xFF81C784);
  static const Color _greenBackground = Color(0xFF0D1F0D);
  static const Color _greenSurface = Color(0xFF1B3D1B);
  static const Color _greenCard = Color(0xFF2E5A2E);

  // ==================== RED THEME ====================
  static const Color _redPrimary = Color(0xFFE53935);
  static const Color _redSecondary = Color(0xFFFF8A80);
  static const Color _redBackground = Color(0xFF1F0C0C);
  static const Color _redSurface = Color(0xFF2D1515);
  static const Color _redCard = Color(0xFF3D1F1F);

  // ==================== BLUE THEME ====================
  static const Color _bluePrimary = Color(0xFF2196F3);
  static const Color _blueSecondary = Color(0xFF64B5F6);
  static const Color _blueBackground = Color(0xFF0A1929);
  static const Color _blueSurface = Color(0xFF132F4C);
  static const Color _blueCard = Color(0xFF173A5E);

  // Common colors
  static const Color errorColor = Color(0xFFE94560);
  static const Color successColor = Color(0xFF2ECC71);
  static const Color warningColor = Color(0xFFF39C12);
  static const Color infoColor = Color(0xFF3498DB);

  // Get theme based on mode
  static ThemeData getTheme(AppThemeMode mode, Brightness brightness) {
    switch (mode) {
      case AppThemeMode.dark:
        return darkTheme;
      case AppThemeMode.light:
        return lightTheme;
      case AppThemeMode.indigo:
        return indigoTheme;
      case AppThemeMode.teal:
        return tealTheme;
      case AppThemeMode.gold:
        return goldTheme;
      case AppThemeMode.yellow:
        return yellowTheme;
      case AppThemeMode.purple:
        return purpleTheme;
      case AppThemeMode.green:
        return greenTheme;
      case AppThemeMode.red:
        return redTheme;
      case AppThemeMode.blue:
        return blueTheme;
      case AppThemeMode.system:
        return brightness == Brightness.dark ? darkTheme : lightTheme;
    }
  }

  // Get theme colors for preview
  static ThemeColors getThemeColors(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return ThemeColors(_darkPrimary, _darkSecondary, _darkBackground);
      case AppThemeMode.light:
        return ThemeColors(_lightPrimary, _lightSecondary, _lightBackground);
      case AppThemeMode.indigo:
        return ThemeColors(_indigoPrimary, _indigoSecondary, _indigoBackground);
      case AppThemeMode.teal:
        return ThemeColors(_tealPrimary, _tealSecondary, _tealBackground);
      case AppThemeMode.gold:
        return ThemeColors(_goldPrimary, _goldSecondary, _goldBackground);
      case AppThemeMode.yellow:
        return ThemeColors(_yellowPrimary, _yellowSecondary, _yellowBackground);
      case AppThemeMode.purple:
        return ThemeColors(_purplePrimary, _purpleSecondary, _purpleBackground);
      case AppThemeMode.green:
        return ThemeColors(_greenPrimary, _greenSecondary, _greenBackground);
      case AppThemeMode.red:
        return ThemeColors(_redPrimary, _redSecondary, _redBackground);
      case AppThemeMode.blue:
        return ThemeColors(_bluePrimary, _blueSecondary, _blueBackground);
      case AppThemeMode.system:
        return ThemeColors(_darkPrimary, _darkSecondary, _darkBackground);
    }
  }

  // ==================== DARK THEME ====================
  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      secondary: _darkSecondary,
      background: _darkBackground,
      surface: _darkSurface,
      card: _darkCard,
      onPrimary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
    );
  }

  // ==================== LIGHT THEME ====================
  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      primary: _lightPrimary,
      secondary: _lightSecondary,
      background: _lightBackground,
      surface: _lightSurface,
      card: _lightCard,
      onPrimary: Colors.white,
      onSurface: const Color(0xFF1A1A2E),
      onBackground: const Color(0xFF1A1A2E),
    );
  }

  // ==================== INDIGO THEME ====================
  static ThemeData get indigoTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      primary: _indigoPrimary,
      secondary: _indigoSecondary,
      background: _indigoBackground,
      surface: _indigoSurface,
      card: _indigoCard,
      onPrimary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
    );
  }

  // ==================== TEAL THEME ====================
  static ThemeData get tealTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      primary: _tealPrimary,
      secondary: _tealSecondary,
      background: _tealBackground,
      surface: _tealSurface,
      card: _tealCard,
      onPrimary: Colors.black,
      onSurface: Colors.white,
      onBackground: Colors.white,
    );
  }

  // ==================== GOLD THEME ====================
  static ThemeData get goldTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      primary: _goldPrimary,
      secondary: _goldSecondary,
      background: _goldBackground,
      surface: _goldSurface,
      card: _goldCard,
      onPrimary: Colors.black,
      onSurface: Colors.white,
      onBackground: Colors.white,
    );
  }

  // ==================== YELLOW THEME ====================
  static ThemeData get yellowTheme {
    return _buildTheme(
      brightness: Brightness.light,
      primary: _yellowPrimary,
      secondary: _yellowSecondary,
      background: _yellowBackground,
      surface: _yellowSurface,
      card: _yellowCard,
      onPrimary: Colors.black,
      onSurface: const Color(0xFF1A1A2E),
      onBackground: const Color(0xFF1A1A2E),
    );
  }

  // ==================== PURPLE THEME ====================
  static ThemeData get purpleTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      primary: _purplePrimary,
      secondary: _purpleSecondary,
      background: _purpleBackground,
      surface: _purpleSurface,
      card: _purpleCard,
      onPrimary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
    );
  }

  // ==================== GREEN THEME ====================
  static ThemeData get greenTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      primary: _greenPrimary,
      secondary: _greenSecondary,
      background: _greenBackground,
      surface: _greenSurface,
      card: _greenCard,
      onPrimary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
    );
  }

  // ==================== RED THEME ====================
  static ThemeData get redTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      primary: _redPrimary,
      secondary: _redSecondary,
      background: _redBackground,
      surface: _redSurface,
      card: _redCard,
      onPrimary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
    );
  }

  // ==================== BLUE THEME ====================
  static ThemeData get blueTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      primary: _bluePrimary,
      secondary: _blueSecondary,
      background: _blueBackground,
      surface: _blueSurface,
      card: _blueCard,
      onPrimary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
    );
  }

  // ==================== THEME BUILDER ====================
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color card,
    required Color onPrimary,
    required Color onSurface,
    required Color onBackground,
  }) {
    final bool isDark = brightness == Brightness.dark;
    final Color textPrimary = onSurface;
    final Color textSecondary = onSurface.withValues(alpha: 0.7);
    final Color textDisabled = onSurface.withValues(alpha: 0.4);
    final Color dividerColor = onSurface.withValues(alpha: 0.12);
    final Color outline = onSurface.withValues(alpha: 0.3);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: background,

      // Color Scheme
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primary.withValues(alpha: 0.2),
        onPrimaryContainer: primary,
        secondary: secondary,
        onSecondary: isDark ? Colors.black : Colors.white,
        secondaryContainer: secondary.withValues(alpha: 0.2),
        onSecondaryContainer: secondary,
        tertiary: secondary,
        onTertiary: isDark ? Colors.black : Colors.white,
        tertiaryContainer: secondary.withValues(alpha: 0.15),
        onTertiaryContainer: secondary,
        error: errorColor,
        onError: Colors.white,
        errorContainer: errorColor.withValues(alpha: 0.2),
        onErrorContainer: errorColor,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: card,
        outline: outline,
        outlineVariant: dividerColor,
        shadow: Colors.black,
        scrim: Colors.black54,
        inverseSurface: isDark ? Colors.white : Colors.black87,
        onInverseSurface: isDark ? Colors.black : Colors.white,
        inversePrimary: primary,
      ),

      // App Bar Theme (Premium Sleek Design)
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 3,
        backgroundColor: background,
        surfaceTintColor: primary,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: textPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: brightness,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: card,
        elevation: isDark ? 4 : 2,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
        surfaceTintColor: primary,
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.2),
        surfaceTintColor: primary,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary, size: 26);
          }
          return IconThemeData(color: textSecondary, size: 24);
        }),
      ),

      // Navigation Rail Theme
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.2),
        selectedIconTheme: IconThemeData(color: primary, size: 26),
        unselectedIconTheme: IconThemeData(color: textSecondary, size: 24),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: textSecondary, fontSize: 12),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 6,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: textDisabled, fontSize: 14),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: primary.withValues(alpha: 0.3),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 8,
        surfaceTintColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        elevation: 8,
        surfaceTintColor: primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        modalBackgroundColor: surface,
        modalElevation: 8,
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? card : surface,
        contentTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        actionTextColor: primary,
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: primary.withValues(alpha: 0.3),
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.2),
        valueIndicatorColor: primary,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primary.withValues(alpha: 0.2),
        circularTrackColor: primary.withValues(alpha: 0.2),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.3),
        labelStyle: TextStyle(color: textPrimary, fontSize: 14),
        secondaryLabelStyle: TextStyle(color: textSecondary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: outline),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.5);
          }
          return textDisabled.withValues(alpha: 0.3);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return outline;
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: outline, width: 2),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return textSecondary;
        }),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: IconThemeData(color: textPrimary, size: 24),

      // Primary Icon Theme
      primaryIconTheme: IconThemeData(color: primary, size: 24),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 40,
        iconColor: textSecondary,
        textColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: primary,
        elevation: 8,
        width: 300,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
        ),
      ),

      // Badge Theme
      badgeTheme: BadgeThemeData(
        backgroundColor: errorColor,
        textColor: Colors.white,
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),

      // Popup Menu Theme (Slim & Compact)
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: dividerColor, width: 0.8),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: -0.25,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.5,
        ),
      ),

      fontFamily: 'Roboto',
    );
  }

  // Helper gradients
  static BoxDecoration primaryGradient(AppThemeMode mode) {
    final colors = getThemeColors(mode);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.primary, colors.secondary],
      ),
    );
  }
}

// Theme colors helper class
class ThemeColors {
  final Color primary;
  final Color secondary;
  final Color background;

  const ThemeColors(this.primary, this.secondary, this.background);
}
