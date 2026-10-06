import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta "Dark Radar" — a mesma identidade do redesign no Figma e do
/// protótipo gerado no Figma Make.
class AppColors {
  static const bg = Color(0xFF0A0D12);
  static const surface = Color(0xFF12161F);
  static const surfaceAlt = Color(0xFF171C27);
  static const surfaceHigh = Color(0xFF1B2330);
  static const line = Color(0xFF232938);
  static const lineSoft = Color(0xFF1C2531);
  static const text = Color(0xFFF2F6FB);
  static const muted = Color(0xFF8A93A6);
  static const mutedDark = Color(0xFF5E687C);
  static const green = Color(0xFF37FF8B);
  static const greenDeep = Color(0xFF0F8F65);
  static const greenSoft = Color(0x1A37FF8B); // ~10% opacity
  static const purple = Color(0xFF8B5CF6);
  static const purpleSoft = Color(0x1F8B5CF6); // ~12% opacity
  static const danger = Color(0xFFFF5470);
  static const dangerSoft = Color(0x1AFF5470); // ~10% opacity
  static const blue = Color(0xFF66A3FF);
  static const blueSoft = Color(0x1A66A3FF);
  static const amber = Color(0xFFF6B94A);
  static const amberSoft = Color(0x1AF6B94A);
  static const onAccent = Color(0xFF06120E);
}

/// Estilos de texto nomeados, espelhando as classes do CSS original
/// (Space Grotesk pros títulos, JetBrains Mono pra dados/labels, Inter
/// pro corpo). Usados diretamente pelos widgets em vez de depender só
/// do TextTheme do Material.
class AppText {
  static TextStyle get h1 => GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        letterSpacing: -0.5,
        height: 1.05,
      );
  static TextStyle get h2 => GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        letterSpacing: -0.5,
      );
  static TextStyle get title => GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );
  static TextStyle get cardTitle => GoogleFonts.spaceGrotesk(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
        height: 1.5,
      );
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      );
  static TextStyle get eyebrow => GoogleFonts.jetBrainsMono(
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        color: AppColors.green,
        letterSpacing: 2,
      );
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
        letterSpacing: 0.5,
      );
  static TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
        fontSize: 9,
        fontWeight: FontWeight.w500,
        color: AppColors.mutedDark,
        letterSpacing: 1,
      );
  static TextStyle get price => GoogleFonts.jetBrainsMono(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      );
  static TextStyle get priceLg => GoogleFonts.jetBrainsMono(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      );
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        brightness: Brightness.dark,
      ),
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.green : AppColors.line,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.onAccent : AppColors.muted,
        ),
      ),
      dividerColor: AppColors.lineSoft,
    );
  }
}
