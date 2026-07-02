import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Egg Guardian Design System
/// All colors, typography, and decoration constants live here.
class EgTheme {
  EgTheme._();

  // ── Palette ──────────────────────────────────────────────────────────
  static const Color bgDeep     = Color(0xFF060B14);
  static const Color bgBase     = Color(0xFF0D1627);
  static const Color bgCard     = Color(0xFF111D35);
  static const Color bgElevated = Color(0xFF162040);
  static const Color bgInput    = Color(0xFF1A2845);

  static const Color accent       = Color(0xFFF59E0B);
  static const Color accentDark   = Color(0xFFD97706);
  static const Color accentLight  = Color(0xFFFBBF24);

  static const Color success = Color(0xFF10B981);
  static const Color danger  = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF97316);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted  = Color(0xFF475569);

  static const Color border     = Color(0xFF1E3A5F);
  static const Color borderFaint = Color(0xFF1A2845);

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF060B14), Color(0xFF0D1627), Color(0xFF081020)],
    stops: [0, 0.5, 1],
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentLight, accent, accentDark],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF111D35), Color(0xFF0D1627)],
  );

  // ── Typography ────────────────────────────────────────────────────────
  static TextStyle display(double size) => GoogleFonts.outfit(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static TextStyle heading(double size) => GoogleFonts.outfit(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle body(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
        color: color ?? textPrimary,
      );

  static TextStyle label(double size) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static TextStyle mono(double size) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  // ── Radius ────────────────────────────────────────────────────────────
  static const BorderRadius r8  = BorderRadius.all(Radius.circular(8));
  static const BorderRadius r12 = BorderRadius.all(Radius.circular(12));
  static const BorderRadius r16 = BorderRadius.all(Radius.circular(16));
  static const BorderRadius r24 = BorderRadius.all(Radius.circular(24));
  static const BorderRadius r32 = BorderRadius.all(Radius.circular(32));

  // ── Card decoration ───────────────────────────────────────────────────
  static BoxDecoration card({Color? borderColor, double borderWidth = 1}) =>
      BoxDecoration(
        gradient: cardGradient,
        borderRadius: r16,
        border: Border.all(
          color: borderColor ?? border,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration accentCard() => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1F2D10), Color(0xFF0D1627)],
    ),
    borderRadius: r16,
    border: Border.all(color: accent.withOpacity(0.3)),
    boxShadow: [
      BoxShadow(color: accent.withOpacity(0.08), blurRadius: 24, spreadRadius: 2),
    ],
  );

  // ── Input decoration ──────────────────────────────────────────────────
  static InputDecoration inputDecoration(String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        prefixIcon: icon != null ? Icon(icon, color: textMuted, size: 20) : null,
        filled: true,
        fillColor: bgInput,
        enabledBorder: OutlineInputBorder(
          borderRadius: r12,
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: r12,
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: r12,
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: r12,
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  // ── Button styles ─────────────────────────────────────────────────────
  static ButtonStyle primaryButton() => ElevatedButton.styleFrom(
    backgroundColor: accent,
    foregroundColor: Colors.black,
    minimumSize: const Size(double.infinity, 52),
    shape: const RoundedRectangleBorder(borderRadius: r12),
    textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
    elevation: 0,
  );

  static ButtonStyle secondaryButton() => OutlinedButton.styleFrom(
    foregroundColor: textPrimary,
    side: const BorderSide(color: border),
    minimumSize: const Size(double.infinity, 52),
    shape: const RoundedRectangleBorder(borderRadius: r12),
    textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
  );

  // ── App ThemeData ─────────────────────────────────────────────────────
  static ThemeData themeData() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgBase,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      surface: bgCard,
      onPrimary: Colors.black,
      onSurface: textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bgBase,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      iconTheme: const IconThemeData(color: textSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bgCard,
      selectedItemColor: accent,
      unselectedItemColor: textMuted,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: accent,
      labelColor: accent,
      unselectedLabelColor: textMuted,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: r16,
        side: const BorderSide(color: border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: bgElevated,
      contentTextStyle: GoogleFonts.inter(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: r12),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Temperature color utility
Color tempColor(double? temp, {double minTemp = 35.0, double maxTemp = 39.0}) {
  if (temp == null) return EgTheme.textMuted;
  if (temp < minTemp) return EgTheme.info;
  if (temp > maxTemp) return EgTheme.danger;
  return EgTheme.success;
}

String tempStatus(double? temp, {double minTemp = 35.0, double maxTemp = 39.0}) {
  if (temp == null) return 'No data';
  if (temp < minTemp) return 'Too Cold';
  if (temp > maxTemp) return 'Too Hot';
  return 'Optimal';
}
