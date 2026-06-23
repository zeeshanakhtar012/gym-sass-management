import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand / Primary — warm gold
  static const primary = Color(0xFFC9A96E);
  static const primaryDark = Color(0xFFA8884A);
  static const primaryLight = Color(0xFFE8D5A8);
  static const primarySurface = Color(0xFF2A2418);

  // Accent — vibrant electric cyan (pops against dark bg)
  static const accent = Color(0xFF00D4AA);

  // Status
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFEAB308);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Light theme (legacy / fallback)
  static const bgLight = Color(0xFFF8F6F3);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE5E0D8);
  static const textPrimaryL = Color(0xFF1C1917);
  static const textSecondaryL = Color(0xFF6B6560);

  // Dark theme — luxury black / charcoal
  static const bgDark = Color(0xFF0A0A0A);
  static const surfaceDark = Color(0xFF141414);
  static const surfaceElevated = Color(0xFF1E1E1E);
  static const borderDark = Color(0xFF2A2A2A);
  static const textPrimaryD = Color(0xFFF5F5F0);
  static const textSecondaryD = Color(0xFFA09890);

  // Utility
  static const neutralGray = Color(0xFF8C8C8C);
  static const shimmerBase = Color(0xFF1E1E1E);
  static const shimmerHighlight = Color(0xFF2A2A2A);
}
