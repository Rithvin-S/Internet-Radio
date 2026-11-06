import 'package:flutter/material.dart';

/// PulseCast Design Tokens - Aurora Dark Color Palette
class AppColors {
  AppColors._();

  // Primary Brand & Accents
  static const Color primary = Color(0xFF6366F1); // Indigo / Electric Purple
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  static const Color secondary = Color(0xFFDB2777); // Pink / Neon Magenta
  static const Color secondaryLight = Color(0xFFF472B6);

  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentViolet = primary;
  static const Color accentCoral = Color(0xFFEF4444);

  // Backgrounds & Surfaces (Aurora Deep Dark)
  static const Color background = Color(0xFF0B0F19); // Ultra deep space
  static const Color surface = Color(0xFF111827); // Dark card base
  static const Color surfaceElevated = Color(0xFF1F2937); // Raised sheets & modals
  static const Color surfaceHighlight = Color(0xFF374151); // Interactive borders

  // Semantic Surface Aliases
  static const Color cardSurface = surface;
  static const Color borderSubtle = border;

  // Live Radio Status Colors
  static const Color liveIndicator = Color(0xFFEF4444); // Live Pulse Red
  static const Color buffering = Color(0xFFF59E0B);
  static const Color connected = Color(0xFF10B981);
  static const Color disconnected = Color(0xFF6B7280);

  // Typography Colors
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);

  // Borders & Dividers
  static const Color border = Color(0xFF1F2937);
  static const Color borderLight = Color(0xFF374151);
  static const Color divider = Color(0xFF1F2937);

  // Aurora Gradients
  static const LinearGradient auroraGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient playerBackgroundGradient = LinearGradient(
    colors: [
      Color(0xFF1E1B4B), // Deep indigo
      Color(0xFF0B0F19), // Dark base
      Color(0xFF0B0F19),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFF172033),
      Color(0xFF111827),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient liveBadgeGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );
}
