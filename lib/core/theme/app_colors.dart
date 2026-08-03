import 'package:flutter/material.dart';

/// SFMS "Agro-Modernist" palette — the exact Material 3 tokens from the design
/// system (DESIGN.md). Kept as raw constants so both the [ColorScheme] and any
/// bespoke widgets can reference them directly.
abstract final class AppColors {
  // Primary — deep agricultural green (growth, main actions).
  static const primary = Color(0xFF0D631B);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF2E7D32);
  static const onPrimaryContainer = Color(0xFFCBFFC2);
  static const inversePrimary = Color(0xFF88D982);

  // Secondary — grounding brown (organisational elements).
  static const secondary = Color(0xFF7A5649);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFFDCDBC);
  static const onSecondaryContainer = Color(0xFF795548);

  // Tertiary — earthy orange (alerts, active work).
  static const tertiary = Color(0xFF8E3D00);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFB45000);
  static const onTertiaryContainer = Color(0xFFFFEEE6);

  // Error.
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Surfaces — off-white "paper" for low glare / outdoor readability.
  static const surface = Color(0xFFF9F9F9);
  static const surfaceDim = Color(0xFFDADADA);
  static const surfaceBright = Color(0xFFF9F9F9);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F3F3);
  static const surfaceContainer = Color(0xFFEEEEEE);
  static const surfaceContainerHigh = Color(0xFFE8E8E8);
  static const surfaceContainerHighest = Color(0xFFE2E2E2);
  static const onSurface = Color(0xFF1A1C1C);
  static const onSurfaceVariant = Color(0xFF40493D);
  static const surfaceVariant = Color(0xFFE2E2E2);

  static const outline = Color(0xFF707A6C);
  static const outlineVariant = Color(0xFFBFCABA);
  static const inverseSurface = Color(0xFF2F3131);
  static const onInverseSurface = Color(0xFFF1F1F1);
  static const surfaceTint = Color(0xFF1B6D24);
  static const shadow = Color(0xFF000000);
  static const scrim = Color(0xFF000000);

  // Fixed accent tokens used for chips / badges in the design.
  static const primaryFixed = Color(0xFFA3F69C);
  static const primaryFixedDim = Color(0xFF88D982);
  static const onPrimaryFixed = Color(0xFF002204);
  static const onPrimaryFixedVariant = Color(0xFF005312);
  static const secondaryFixed = Color(0xFFFFDBCF);
  static const secondaryFixedDim = Color(0xFFEBBCAC);
  static const onSecondaryFixed = Color(0xFF2E150B);
  static const onSecondaryFixedVariant = Color(0xFF603F33);
  static const tertiaryFixed = Color(0xFFFFDBCA);
  static const tertiaryFixedDim = Color(0xFFFFB68F);
  static const onTertiaryFixed = Color(0xFF331200);
  static const onTertiaryFixedVariant = Color(0xFF773200);

  static const background = Color(0xFFF9F9F9);
  static const onBackground = Color(0xFF1A1C1C);
}
