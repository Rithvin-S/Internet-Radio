import 'package:flutter/material.dart';

/// PulseCast Exact Reference Design Tokens
/// Precisely matched to the reference UI specification:
/// Deep near-black background, vibrant electric-lime accents, clean dark card chassis.
class AppColors {
  AppColors._();

  // Primary Brand & Electric Lime Accents
  static const Color primary = Color(0xFF2CE045); // Vibrant reference lime green
  static const Color primaryLight = Color(0xFF47EA5E); // Crisp bright lime
  static const Color primaryDark = Color(0xFF1CB532); // Deep forest green
  static const Color brandGreenDark = Color(0xFF102616); // Subtle green container fill

  static const Color secondary = Color(0xFF22C55E);
  static const Color secondaryLight = Color(0xFF4ADE80);

  // Semantic & UI Accents
  static const Color accentCyan = Color(0xFF2CE045); // Unified to reference lime green
  static const Color accentLime = Color(0xFF2CE045);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentEmerald = Color(0xFF2CE045);
  static const Color accentViolet = Color(0xFF1CB532);
  static const Color accentCoral = Color(0xFFEF4444); // Crimson for alerts

  // Backgrounds & Surfaces (Pitch black & clean dark chassis)
  static const Color background = Color(0xFF0C0D0F); // Pitch black backdrop
  static const Color surface = Color(0xFF16181D); // Clean dark card surface
  static const Color surfaceElevated = Color(0xFF1C1F25); // Raised action deck
  static const Color surfaceHighlight = Color(0xFF252932); // Input & interactive chips

  // Semantic Surface Aliases
  static const Color cardSurface = surface;
  static const Color borderSubtle = Color(0xFF20232A);

  // Live Radio Status Colors
  static const Color liveIndicator = Color(0xFF2CE045); // Reference bright green LIVE
  static const Color buffering = Color(0xFFF59E0B);
  static const Color connected = Color(0xFF2CE045);
  static const Color disconnected = Color(0xFF64748B);

  // Typography Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure white
  static const Color textSecondary = Color(0xFF8E95A0); // Refined medium grey
  static const Color textMuted = Color(0xFF606672); // Slate grey
  static const Color textDisabled = Color(0xFF404550);

  // Borders & Dividers
  static const Color border = Color(0xFF22252C); // Subtle hairline card border
  static const Color borderLight = Color(0xFF2D323C);
  static const Color borderActive = Color(0xFF2CE045); // Active selection border
  static const Color divider = Color(0xFF1E2128);

  // Logout Button Specific Tokens (from Reference Settings screen)
  static const Color logoutButtonBg = Color(0xFF251315); // Dark reddish brown
  static const Color logoutText = Color(0xFFFF4D4D); // Crisp coral red

  // Gradients
  static const LinearGradient auroraGradient = LinearGradient(
    colors: [
      Color(0xFF15331C),
      Color(0xFF0C0D0F),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient vinylGrooveGradient = LinearGradient(
    colors: [
      Color(0xFF1C2228),
      Color(0xFF0F1115),
      Color(0xFF222A32),
      Color(0xFF0F1115),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient greenWaveGradient = LinearGradient(
    colors: [
      Color(0xFF0B2414),
      Color(0x000C0D0F),
    ],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  );
}
