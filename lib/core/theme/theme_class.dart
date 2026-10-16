import 'package:flutter/material.dart';

import 'app_color.dart';
import 'spacing_tokens.dart';

class ThemeClass {
  ThemeClass._();

  static const double _radius = 14;

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: AppColor.primaryColor,
      onPrimary: AppColor.whiteColor,
      secondary: AppColor.secondryColor,
      onSecondary: AppColor.whiteColor,
      surface: AppColor.whiteColor,
      onSurface: AppColor.blackColor,
      surfaceContainerHighest: AppColor.lightGreyColor,
      outline: AppColor.borderColor,
      outlineVariant: AppColor.borderColor,
    );

    return ThemeData(
      colorScheme: colorScheme,
      // Cairo renders both Arabic and Latin, so one family covers the
      // whole bilingual UI. Every AppFonts style inherits it.
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: AppColor.whiteColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColor.whiteColor,
        foregroundColor: AppColor.blackColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
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
            horizontal: SpacingTokens.lg,
            vertical: SpacingTokens.md,
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
            horizontal: SpacingTokens.lg,
            vertical: SpacingTokens.md,
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
          horizontal: SpacingTokens.lg,
          vertical: SpacingTokens.md,
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
          borderSide: const BorderSide(color: AppColor.primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColor.primaryColor),
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
}

