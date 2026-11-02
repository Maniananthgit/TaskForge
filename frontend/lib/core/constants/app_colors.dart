import 'package:flutter/material.dart';

class AppColors {
  // Dark Palette (Default Enterprise Theme)
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF131B2B);
  static const Color darkCard = Color(0xFF182235);
  static const Color darkCardBorder = Color(0xFF24324D);

  // Light Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);

  // Brand Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF06B6D4); // Cyan

  // Functional Colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color successBg = Color(0xFF064E3B);
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningBg = Color(0xFF78350F);
  static const Color danger = Color(0xFFEF4444); // Rose
  static const Color dangerBg = Color(0xFF7F1D1D);
  static const Color error = danger;
  static const Color errorBg = dangerBg;
  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoBg = Color(0xFF1E3A8A);

  // Neutral Grays
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF192338), Color(0xFF121927)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
