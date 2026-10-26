import 'package:flutter/material.dart';

import 'app_color.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

class ThemeClass {
  ThemeClass._();

  static const double _radius = 12;

  /// Builds the light theme. Every [AppFonts] style leaves its family unset, so
  /// the whole UI follows the family chosen here.
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: AppColor.primaryColor,
      onPrimary: AppColor.whiteColor,
      secondary: AppColor.secondaryStrong,
      onSecondary: AppColor.whiteColor,
      surface: AppColor.whiteColor,
      onSurface: AppColor.blackColor,
      onSurfaceVariant: AppColor.adminMuted,
      surfaceContainerHighest: AppColor.lightGreyColor,
      outline: AppColor.borderColor,
      outlineVariant: AppColor.borderColor,
      error: AppColor.errorColor,
      onError: AppColor.whiteColor,
    );

    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: 'IBM Plex Sans Arabic',
      scaffoldBackgroundColor: AppColor.surfaceColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColor.whiteColor,
        foregroundColor: AppColor.blackColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColor.borderColor,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColor.greyColor),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primaryColor,
          foregroundColor: AppColor.whiteColor,
          disabledBackgroundColor: AppColor.lightGreyColor,
          disabledForegroundColor: AppColor.greyColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColor.primaryColor,
          side: const BorderSide(color: AppColor.primaryColor),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColor.primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColor.lightGreyColor,
        hintStyle: const TextStyle(color: AppColor.greyColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.lg,
          vertical: AppDimensions.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColor.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColor.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(
            color: AppColor.secondaryStrong,
            width: AppDimensions.borderStrong,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColor.errorColor),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColor.whiteColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: AppColor.borderColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColor.whiteColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColor.primaryColor;
          }
          return Colors.transparent;
        }),
        side: const BorderSide(color: AppColor.borderColor),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColor.whiteColor;
          }
          return AppColor.greyColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColor.primaryColor;
          }
          return AppColor.lightGreyColor;
        }),
      ),
    );
  }

  /// Builds the dark theme for the active language. Mirrors [light] so the
  /// same widgets look intentional in both appearances.
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: AppColor.primaryColor,
      onPrimary: AppColor.whiteColor,
      secondary: AppColor.secondaryColor,
      onSecondary: AppColor.primaryColor,
      surface: AppColor.darkSurface,
      onSurface: AppColor.darkText,
      onSurfaceVariant: AppColor.darkTextSecondary,
      surfaceContainerHighest: AppColor.darkSurfaceContainer,
      surfaceContainerLow: AppColor.darkSurface,
      surfaceContainer: AppColor.darkSurfaceContainer,
      outline: AppColor.darkBorder,
      outlineVariant: AppColor.darkBorder,
      error: AppColor.errorColor,
      onError: AppColor.whiteColor,
    );

    return ThemeData(
      colorScheme: colorScheme,
      fontFamily: 'IBM Plex Sans Arabic',
      scaffoldBackgroundColor: AppColor.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColor.darkSurface,
        foregroundColor: AppColor.darkText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColor.darkBorder,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColor.darkTextSecondary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primaryColor,
          foregroundColor: AppColor.whiteColor,
          disabledBackgroundColor: AppColor.darkCard,
          disabledForegroundColor: AppColor.darkTextSecondary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColor.primaryColor,
          side: const BorderSide(color: AppColor.primaryColor),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColor.primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColor.darkSurfaceContainer,
        hintStyle: const TextStyle(color: AppColor.darkTextSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.lg,
          vertical: AppDimensions.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColor.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColor.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(
            color: AppColor.secondaryColor,
            width: AppDimensions.borderStrong,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColor.errorColor),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColor.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: const BorderSide(color: AppColor.darkBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColor.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColor.primaryColor;
          }
          return Colors.transparent;
        }),
        side: const BorderSide(color: AppColor.darkBorder),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColor.whiteColor;
          }
          return AppColor.darkTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColor.primaryColor;
          }
          return AppColor.darkCard;
        }),
      ),
    );
  }
}
