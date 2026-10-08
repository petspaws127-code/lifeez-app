import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette: ivory background, light fresh green + gold accents.
class AppColors {
  static const Color ivory = Color(0xFFFFFCF4);
  static const Color ivoryDeep = Color(0xFFF7F1E3);
  static const Color deepGreen = Color(0xFF1E7D4F);
  static const Color greenMid = Color(0xFF34A46F);
  static const Color greenSoft = Color(0xFFDFF2E5);
  static const Color gold = Color(0xFFC9A227);
  static const Color goldLight = Color(0xFFF5DC8A);
  static const Color goldSoft = Color(0xFFFBF3DC);
  static const Color ink = Color(0xFF20302A);
  static const Color muted = Color(0xFF6E7F75);
  static const Color danger = Color(0xFFD64545);
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF128C7E);
  static const Color whatsappBg = Color(0xFFEFE7D8);
}

/// Modern 3D design language: layered cards, gradient tiles, soft shadows.
class AppTheme {
  /// Set by the app root whenever the active [ThemeMode] resolves;
  /// keeps static card helpers in sync with the theme.
  /// Uses an explicit override when set via [setDark]; otherwise falls back
  /// to the actual system brightness so cards are never out of sync.
  static bool? _darkOverride;
  static void setDark(bool v) => _darkOverride = v;
  static bool get _dark =>
      _darkOverride ??
      SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
  static bool get isDark => _dark;

  /// Card surface color that follows the active theme.
  /// Dark mode: pure black as requested.
  static Color get card =>
      _dark ? const Color(0xFF000000) : Colors.white;

  /// Text color for BLACK backgrounds: always white.
  static Color get textOnBlack => const Color(0xFFFFFFFF);

  /// Text color for WHITE backgrounds: always black.
  static Color get textOnWhite => const Color(0xFF000000);

  /// Adaptive text color: white in dark mode (black bg), black in light mode (white bg).
  /// Use this for text on theme-aware surfaces.
  static Color get textOnSurface =>
      _dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final text = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ivory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.deepGreen,
        primary: AppColors.deepGreen,
        secondary: AppColors.gold,
        surface: Colors.white,
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.deepGreen,
        unselectedItemColor: AppColors.muted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.deepGreen,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.poppins(color: AppColors.muted, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// Layered white card with soft double shadow (the "3D" surface).
  static BoxDecoration card3D({double radius = 22}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: _dark
                ? const Color(0x40000000)
                : const Color(0x0D1E7D4F),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: _dark
                ? const Color(0x10000000)
                : const Color(0x08C9A227),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );

  /// Dark theme: pure black surfaces, white text. No blue.
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final text = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFFFFFFFF),
      displayColor: const Color(0xFFFFFFFF),
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF000000),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.deepGreen,
        brightness: Brightness.dark,
        primary: const Color(0xFF5CC47A),
        secondary: AppColors.gold,
        surface: const Color(0xFF000000),
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF000000),
        foregroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFFFFF),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF000000),
        selectedItemColor: Color(0xFF5CC47A),
        unselectedItemColor: Color(0xFFFFFFFF),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF2E7D4F),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF000000),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: GoogleFonts.poppins(
            color: const Color(0xFFFFFFFF), fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF000000),
      ),
    );
  }

  /// Fresh green hero gradient card.
  static BoxDecoration heroGradient({double radius = 26}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepGreen, AppColors.greenMid],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E1E7D4F),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      );

  /// Gold gradient card (accents, tips).
  static BoxDecoration goldGradient({double radius = 22}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gold, AppColors.goldLight],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40C9A227),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      );

  /// 3D gradient icon tile used by [CategoryIcon].
  static BoxDecoration tile3D(List<Color> colors, {double radius = 18}) =>
      BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          const BoxShadow(
            color: Color(0x1AFFFFFF),
            blurRadius: 5,
            offset: Offset(0, -2),
          ),
        ],
      );

  /// WhatsApp-style chat bubble.
  static BoxDecoration chatBubble({required bool isUser}) => BoxDecoration(
        color: isUser ? const Color(0xFFD9FDD3) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      );
}
