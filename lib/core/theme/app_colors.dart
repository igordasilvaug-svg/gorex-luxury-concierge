import 'package:flutter/material.dart';

/// GOREX LUXURY CONCIERGE — Palette de couleurs officielle
/// Noir • Blanc • Champagne/Doré discret • Gris anthracite
class AppColors {
  AppColors._();

  // Fonds sombres
  static const Color black = Color(0xFF0A0A0B);
  static const Color blackSoft = Color(0xFF111114);
  static const Color anthracite = Color(0xFF1A1A1D);
  static const Color anthraciteLight = Color(0xFF232327);
  static const Color surface = Color(0xFF16161A);
  static const Color surfaceElevated = Color(0xFF1E1E23);

  // Champagne / Or discret
  static const Color champagne = Color(0xFFC6A15B);
  static const Color champagneLight = Color(0xFFD8BC85);
  static const Color champagneDark = Color(0xFFA98643);
  static const Color gold = Color(0xFFBF9B5F);

  // Neutres clairs
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF6F4EF);
  static const Color ivory = Color(0xFFEDEAE2);

  // Gris
  static const Color grey = Color(0xFF8A8A90);
  static const Color greyLight = Color(0xFFB5B5BA);
  static const Color greyDark = Color(0xFF4A4A50);
  static const Color divider = Color(0xFF2A2A2F);

  // Statuts
  static const Color statusNew = Color(0xFF7E8BA3);
  static const Color statusReview = Color(0xFFB08D57);
  static const Color statusProgress = Color(0xFF4E7A9B);
  static const Color statusWaiting = Color(0xFFC79A3E);
  static const Color statusConfirmed = Color(0xFF5A8F6B);
  static const Color statusCompleted = Color(0xFF3F7A5A);
  static const Color statusCancelled = Color(0xFF9B4A4A);
  static const Color urgent = Color(0xFFB03A3A);
  static const Color success = Color(0xFF5A8F6B);

  // Dégradés
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [champagneLight, champagne, champagneDark],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [blackSoft, black],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceElevated, surface],
  );
}
