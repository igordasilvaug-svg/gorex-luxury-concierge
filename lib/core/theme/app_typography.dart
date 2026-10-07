import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typographie élégante — Luxe, corporate, britannique
class AppTypography {
  AppTypography._();

  static const String display = 'Playfair Display';
  static const String body = 'Inter';

  // Tailles & espacement des lettres (élégance)
  static const TextStyle brandTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 6,
    color: AppColors.white,
  );

  static const TextStyle brandTitleSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 4,
    color: AppColors.white,
  );

  static const TextStyle eyebrow = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 4,
    color: AppColors.champagne,
  );

  static const TextStyle displayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.15,
    color: AppColors.white,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.2,
    color: AppColors.white,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.white,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.white,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.greyLight,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.greyLight,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: AppColors.grey,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: AppColors.greyLight,
  );

  static const TextStyle button = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
    color: AppColors.black,
  );

  static const TextStyle numberLarge = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.white,
  );
}
