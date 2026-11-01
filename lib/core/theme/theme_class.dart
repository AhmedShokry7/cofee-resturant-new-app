import 'package:flutter/material.dart';

import 'app_color.dart';
import 'tokens.dart';
import 'typography.dart';

/// The theme: the single place a colour role, a radius, a control height or a
/// text style is decided, so a page never restates any of them.
///
/// One family serves both languages ([AppFontFamily.primary]) and one radius
/// scale serves every shape ([AppRadius] through [AppDimensions]). Anything a
/// component needs that is not here is added here first, never locally.
class ThemeClass {
  ThemeClass._();

  static ThemeData light() {
    const onSurface = AppColor.blackColor;

    final colorScheme = ColorScheme.light(
      primary: AppColor.primaryColor,
      onPrimary: AppColor.whiteColor,
      primaryContainer: AppColor.primarySoft,
      onPrimaryContainer: AppColor.primaryColorDeep,
      secondary: AppColor.secondryColor,
      onSecondary: AppColor.whiteColor,
      tertiary: AppColor.successColorDeep,
      onTertiary: AppColor.whiteColor,
      error: AppColor.errorColor,
      onError: AppColor.whiteColor,
      surface: AppColor.whiteColor,
      onSurface: onSurface,
      surfaceContainerHighest: AppColor.lightGreyColor,
      onSurfaceVariant: AppColor.greyColor,
      outline: AppColor.borderColor,
      outlineVariant: AppColor.borderColor,
      scrim: AppColor.scrimColor,
    );

    final textTheme = buildTextTheme(onSurface);

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.controlRadius),
    );
    const controlPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: AppFontFamily.primary,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColor.whiteColor,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColor.whiteColor,
        foregroundColor: onSurface,
        surfaceTintColor: AppColor.transparent,
        elevation: AppElevation.flat,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(
          size: AppIconSize.xl,
          color: AppColor.blackColor,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColor.borderColor,
        thickness: AppSizes.px1,
        space: AppSizes.px1,
      ),
      iconTheme: const IconThemeData(
        color: AppColor.greyColor,
        size: AppIconSize.xl,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.primaryColor,
          foregroundColor: AppColor.whiteColor,
          disabledBackgroundColor: AppColor.lightGreyColor,
          disabledForegroundColor: AppColor.greyColor,
          elevation: AppElevation.flat,
          minimumSize: const Size(0, AppDimensions.buttonHeight),
          padding: controlPadding,
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColor.transparent,
          foregroundColor: AppColor.primaryColor,
          minimumSize: const Size(0, AppDimensions.buttonHeight),
          side: BorderSide(color: AppColor.primaryColor),
          padding: controlPadding,
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColor.primaryColor,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColor.lightGreyColor,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColor.greyColor),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColor.greyColor),
        contentPadding: controlPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.controlRadius),
          borderSide: const BorderSide(color: AppColor.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.controlRadius),
          borderSide: const BorderSide(color: AppColor.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.controlRadius),
          borderSide: BorderSide(color: AppColor.primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.controlRadius),
          borderSide: const BorderSide(color: AppColor.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.controlRadius),
          borderSide: const BorderSide(color: AppColor.errorColor),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColor.whiteColor,
        surfaceTintColor: AppColor.transparent,
        elevation: AppElevation.flat,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          side: const BorderSide(color: AppColor.borderColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColor.whiteColor,
        surfaceTintColor: AppColor.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      // A sheet is the app's heaviest floating surface: rounder than a card and
      // clipped to the top corners only, which is what Material 3 draws.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColor.whiteColor,
        surfaceTintColor: AppColor.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.r24),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColor.lightGreyColor,
        selectedColor: AppColor.primaryColor,
        side: const BorderSide(color: AppColor.borderColor),
        labelStyle: textTheme.labelLarge,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppDimensions.badgeRadius),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        iconColor: AppColor.greyColor,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColor.secondryColor,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColor.whiteColor,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.controlRadius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColor.primaryColor,
        linearTrackColor: AppColor.lightGreyColor,
        circularTrackColor: AppColor.lightGreyColor,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColor.primaryColor;
          }
          return AppColor.transparent;
        }),
        side: const BorderSide(color: AppColor.borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColor.primaryColor;
          }
          return AppColor.greyColor;
        }),
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
