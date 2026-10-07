import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.champagne,
        onPrimary: AppColors.black,
        secondary: AppColors.champagneLight,
        onSecondary: AppColors.black,
        surface: AppColors.surface,
        onSurface: AppColors.white,
        error: AppColors.urgent,
        onError: AppColors.white,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.greyLight,
        displayColor: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.white),
        titleTextStyle: AppTypography.title,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppColors.divider, width: 0.6),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.6,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.anthracite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: AppTypography.caption,
        labelStyle: AppTypography.label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.divider, width: 0.6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.champagne, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.urgent, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.champagne,
          foregroundColor: AppColors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: AppTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.champagne,
          side: const BorderSide(color: AppColors.champagneDark, width: 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: AppTypography.button.copyWith(color: AppColors.champagne),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.champagne,
          textStyle: AppTypography.label.copyWith(color: AppColors.champagne),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: AppTypography.bodyMedium,
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.divider, width: 0.6),
        ),
        titleTextStyle: AppTypography.headline,
        contentTextStyle: AppTypography.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.blackSoft,
        indicatorColor: AppColors.champagne.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          AppTypography.caption.copyWith(fontSize: 10.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.anthracite,
        side: const BorderSide(color: AppColors.divider, width: 0.6),
        labelStyle: AppTypography.caption,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.champagne,
        unselectedLabelColor: AppColors.grey,
        indicatorColor: AppColors.champagne,
        labelStyle: AppTypography.label,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.champagne,
      ),
    );
  }
}
