import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Design-system type scale (DESIGN.md).
/// Be Vietnam Pro for display/body, Work Sans for labels & numeric data.
abstract final class AppText {
  static TextStyle get headlineLg => GoogleFonts.beVietnamPro(
        fontSize: 30,
        height: 38 / 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineLgMobile => GoogleFonts.beVietnamPro(
        fontSize: 26,
        height: 32 / 26,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineMd => GoogleFonts.beVietnamPro(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get headlineSm => GoogleFonts.beVietnamPro(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyLg => GoogleFonts.beVietnamPro(
        fontSize: 18,
        height: 26 / 18,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get bodyMd => GoogleFonts.beVietnamPro(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  static TextStyle get labelMd => GoogleFonts.workSans(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  static TextStyle get labelSm => GoogleFonts.workSans(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurfaceVariant,
      );

  /// Maps the scale onto Flutter's [TextTheme] slots.
  static TextTheme get textTheme => TextTheme(
        headlineLarge: headlineLg,
        headlineMedium: headlineMd,
        headlineSmall: headlineSm,
        titleLarge: headlineSm,
        titleMedium: GoogleFonts.beVietnamPro(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        labelLarge: labelMd,
        labelMedium: labelMd,
        labelSmall: labelSm,
      );
}
