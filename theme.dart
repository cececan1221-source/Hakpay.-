import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cyber-Manga Dark Mode
class HakTheme {
  static const bg = Color(0xFF0A0614);
  static const bgDeep = Color(0xFF06040F);
  static const surface = Color(0xFF16122A);
  static const surface2 = Color(0xFF1E1836);
  static const card = Color(0xCC1A1430);
  static const neonPurple = Color(0xFF9B6DFF);
  static const neonMagenta = Color(0xFFE040FB);
  static const neonBlue = Color(0xFF64B5F6);
  static const accent = Color(0xFF7C4DFF);
  static const success = Color(0xFF69F0AE);
  static const warning = Color(0xFFFFD54F);
  static const danger = Color(0xFFFF5252);
  static const textPrimary = Color(0xFFF3EEFF);
  static const textSecondary = Color(0xFFB0A8C8);
  static const textMuted = Color(0xFF7A7394);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: surface,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.25),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static BoxDecoration glass({double radius = 18}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: neonPurple.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration spaceBg() => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12081F), Color(0xFF0A0614), Color(0xFF06040F)],
        ),
      );
}
