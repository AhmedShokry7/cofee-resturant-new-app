import 'package:flutter/material.dart';

/// The fonts page: the family, the weights, the sizes, the line heights.
///
/// No screen writes `fontSize:`, `FontWeight.wNNN` or `height:` directly - it
/// takes a style from [AppFonts] or from `Theme.of(context).textTheme`, and
/// `copyWith` is the only way to bend one.

/// The family registered in `pubspec.yaml`, spelled in exactly one place.
///
/// IBM Plex Sans Arabic carries the Latin glyphs too, so the single family
/// serves both languages; the theme no longer switches family per locale.
abstract final class AppFontFamily {
  /// Registered with the 400, 500, 600 and 700 weight files.
  static const String primary = 'IBM Plex Sans Arabic';
}

/// The weights the app bundled a file for - nothing else is drawn.
///
/// A heavier request (w800, w900) would fall back to the 700 file anyway, so a
/// mark that wants emphasis gets [bold] plus colour or size, never a weight the
/// family does not ship.
abstract final class AppFontWeights {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
}

/// Text sizes, each named after its own value.
///
/// A fixed logical size is what survives the move off ScreenUtil: the type the
/// customer chose in the system settings scales it through
/// `MediaQuery.textScaler`, while the width of the window does not.
abstract final class AppFontSizes {
  static const double size10 = 10;
  static const double size11 = 11;
  static const double size12 = 12;
  static const double size13 = 13;
  static const double size14 = 14;
  static const double size15 = 15;
  static const double size16 = 16;
  static const double size18 = 18;
  static const double size20 = 20;
  static const double size22 = 22;
  static const double size24 = 24;
  static const double size26 = 26;
  static const double size28 = 28;
  static const double size32 = 32;
  static const double size36 = 36;
  static const double size40 = 40;
}

/// Line heights. Arabic descends and ascends further than Latin, so running
/// text needs more room than the default metrics give it.
abstract final class AppTextHeights {
  /// A single line: numbers, marks, button labels.
  static const double tight = 1.15;

  /// Headings and titles.
  static const double heading = 1.3;

  /// Body copy and descriptions.
  static const double body = 1.5;

  /// Long passages - the privacy policy and help articles.
  static const double article = 1.75;

  /// The number in a stacked mark (the discount badge), pulled up to its sign.
  static const double mark = 0.85;

  /// The sign under the number of a stacked mark.
  static const double markCaption = 0.75;

  /// A glyph that fills a fixed pill or badge, where any leading at all would
  /// push the pill open.
  static const double inset = 1.0;
}

/// Letter spacing, for the few labels that need air between the glyphs.
abstract final class AppLetterSpacings {
  static const double none = 0.0;
  static const double label = 0.2;
  static const double wide = 0.8;

  /// A card brand name on the payment preview.
  static const double brand = 1.0;

  /// The masked card number, spaced so the groups read as digits, not a word.
  static const double number = 2.0;
}

/// The ready-made text styles: weight and size from [AppFontWeights] and
/// [AppFontSizes] only.
///
/// Every size here is a plain logical pixel, so the type the customer picked in
/// the system settings scales it through `MediaQuery.textScaler` and the width
/// of the window never does.
class AppFonts {
  const AppFonts._();

  static TextStyle base(BuildContext context) =>
      TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color);

  static TextStyle _style(
    BuildContext context,
    FontWeight weight,
    double size,
  ) => base(context).copyWith(fontWeight: weight, fontSize: size);

  // ===== Regular (400) =====
  static TextStyle regular10(BuildContext context) =>
      _style(context, AppFontWeights.regular, AppFontSizes.size10);
  static TextStyle regular12(BuildContext context) =>
      _style(context, AppFontWeights.regular, AppFontSizes.size12);
  static TextStyle regular14(BuildContext context) =>
      _style(context, AppFontWeights.regular, AppFontSizes.size14);
  static TextStyle regular16(BuildContext context) =>
      _style(context, AppFontWeights.regular, AppFontSizes.size16);
  static TextStyle regular18(BuildContext context) =>
      _style(context, AppFontWeights.regular, AppFontSizes.size18);
  static TextStyle regular20(BuildContext context) =>
      _style(context, AppFontWeights.regular, AppFontSizes.size20);
  static TextStyle regular24(BuildContext context) =>
      _style(context, AppFontWeights.regular, AppFontSizes.size24);
  static TextStyle regular28(BuildContext context) =>
      _style(context, AppFontWeights.regular, AppFontSizes.size28);
  static TextStyle regular32(BuildContext context) =>
      _style(context, AppFontWeights.regular, AppFontSizes.size32);

  // ===== Medium (500) =====
  static TextStyle medium10(BuildContext context) =>
      _style(context, AppFontWeights.medium, AppFontSizes.size10);
  static TextStyle medium12(BuildContext context) =>
      _style(context, AppFontWeights.medium, AppFontSizes.size12);
  static TextStyle medium14(BuildContext context) =>
      _style(context, AppFontWeights.medium, AppFontSizes.size14);
  static TextStyle medium16(BuildContext context) =>
      _style(context, AppFontWeights.medium, AppFontSizes.size16);
  static TextStyle medium18(BuildContext context) =>
      _style(context, AppFontWeights.medium, AppFontSizes.size18);
  static TextStyle medium20(BuildContext context) =>
      _style(context, AppFontWeights.medium, AppFontSizes.size20);
  static TextStyle medium24(BuildContext context) =>
      _style(context, AppFontWeights.medium, AppFontSizes.size24);
  static TextStyle medium28(BuildContext context) =>
      _style(context, AppFontWeights.medium, AppFontSizes.size28);
  static TextStyle medium32(BuildContext context) =>
      _style(context, AppFontWeights.medium, AppFontSizes.size32);

  // ===== SemiBold (600) =====
  static TextStyle semiBold10(BuildContext context) =>
      _style(context, AppFontWeights.semiBold, AppFontSizes.size10);
  static TextStyle semiBold12(BuildContext context) =>
      _style(context, AppFontWeights.semiBold, AppFontSizes.size12);
  static TextStyle semiBold14(BuildContext context) =>
      _style(context, AppFontWeights.semiBold, AppFontSizes.size14);
  static TextStyle semiBold16(BuildContext context) =>
      _style(context, AppFontWeights.semiBold, AppFontSizes.size16);
  static TextStyle semiBold18(BuildContext context) =>
      _style(context, AppFontWeights.semiBold, AppFontSizes.size18);
  static TextStyle semiBold20(BuildContext context) =>
      _style(context, AppFontWeights.semiBold, AppFontSizes.size20);
  static TextStyle semiBold24(BuildContext context) =>
      _style(context, AppFontWeights.semiBold, AppFontSizes.size24);
  static TextStyle semiBold28(BuildContext context) =>
      _style(context, AppFontWeights.semiBold, AppFontSizes.size28);
  static TextStyle semiBold32(BuildContext context) =>
      _style(context, AppFontWeights.semiBold, AppFontSizes.size32);

  // ===== Bold (700) =====
  static TextStyle bold12(BuildContext context) =>
      _style(context, AppFontWeights.bold, AppFontSizes.size12);
  static TextStyle bold14(BuildContext context) =>
      _style(context, AppFontWeights.bold, AppFontSizes.size14);
  static TextStyle bold16(BuildContext context) =>
      _style(context, AppFontWeights.bold, AppFontSizes.size16);
  static TextStyle bold18(BuildContext context) =>
      _style(context, AppFontWeights.bold, AppFontSizes.size18);
  static TextStyle bold20(BuildContext context) =>
      _style(context, AppFontWeights.bold, AppFontSizes.size20);
  static TextStyle bold24(BuildContext context) =>
      _style(context, AppFontWeights.bold, AppFontSizes.size24);
  static TextStyle bold28(BuildContext context) =>
      _style(context, AppFontWeights.bold, AppFontSizes.size28);
  static TextStyle bold32(BuildContext context) =>
      _style(context, AppFontWeights.bold, AppFontSizes.size32);
}

/// The TextTheme the rest of the theme is built on.
///
/// These styles carry the Arabic line height from [AppTextHeights], so a screen
/// that is happy with `bodyMedium` gets the correct reading without restating
/// the number.
TextTheme buildTextTheme(Color onSurface) {
  TextStyle style(double size, FontWeight weight, double height) => TextStyle(
    color: onSurface,
    fontFamily: AppFontFamily.primary,
    fontSize: size,
    fontWeight: weight,
    height: height,
  );

  return TextTheme(
    displayLarge: style(
      AppFontSizes.size40,
      AppFontWeights.bold,
      AppTextHeights.heading,
    ),
    displayMedium: style(
      AppFontSizes.size36,
      AppFontWeights.bold,
      AppTextHeights.heading,
    ),
    displaySmall: style(
      AppFontSizes.size32,
      AppFontWeights.bold,
      AppTextHeights.heading,
    ),
    headlineLarge: style(
      AppFontSizes.size28,
      AppFontWeights.bold,
      AppTextHeights.heading,
    ),
    headlineMedium: style(
      AppFontSizes.size24,
      AppFontWeights.semiBold,
      AppTextHeights.heading,
    ),
    headlineSmall: style(
      AppFontSizes.size20,
      AppFontWeights.semiBold,
      AppTextHeights.heading,
    ),
    titleLarge: style(
      AppFontSizes.size20,
      AppFontWeights.semiBold,
      AppTextHeights.heading,
    ),
    titleMedium: style(
      AppFontSizes.size16,
      AppFontWeights.semiBold,
      AppTextHeights.heading,
    ),
    titleSmall: style(
      AppFontSizes.size14,
      AppFontWeights.medium,
      AppTextHeights.heading,
    ),
    bodyLarge: style(
      AppFontSizes.size16,
      AppFontWeights.regular,
      AppTextHeights.body,
    ),
    bodyMedium: style(
      AppFontSizes.size14,
      AppFontWeights.regular,
      AppTextHeights.body,
    ),
    bodySmall: style(
      AppFontSizes.size12,
      AppFontWeights.regular,
      AppTextHeights.body,
    ),
    labelLarge: style(
      AppFontSizes.size14,
      AppFontWeights.semiBold,
      AppTextHeights.tight,
    ),
    labelMedium: style(
      AppFontSizes.size12,
      AppFontWeights.medium,
      AppTextHeights.tight,
    ),
    labelSmall: style(
      AppFontSizes.size10,
      AppFontWeights.medium,
      AppTextHeights.tight,
    ),
  );
}
