import 'package:flutter/material.dart';

/// أوزان الخطوط المعتمدة في التطبيق.
///
/// الواجهات لا تستخدم [FontWeight] مباشرة، بل تشير إلى هذه الأسماء.
abstract final class AppFontWeights {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
}

/// أحجام الخطوط المستخدمة في التطبيق.
///
/// اسم كل حجم يطابق قيمته حتى لا يختلط المقاس عند الاستخدام.
abstract final class AppFontSizes {
  static const double size7_5 = 7.5;
  static const double size8 = 8;
  static const double size8_5 = 8.5;
  static const double size8_8 = 8.8;
  static const double size9 = 9;
  static const double size9_5 = 9.5;
  static const double size10 = 10;
  static const double size10_5 = 10.5;
  static const double size11 = 11;
  static const double size11_5 = 11.5;
  static const double size12 = 12;
  static const double size12_5 = 12.5;
  static const double size13 = 13;
  static const double size14 = 14;
  static const double size14_5 = 14.5;
  static const double size15 = 15;
  static const double size16 = 16;
  static const double size17 = 17;
  static const double size18 = 18;
  static const double size20 = 20;
  static const double size21 = 21;
  static const double size22 = 22;
  static const double size23 = 23;
  static const double size24 = 24;
  static const double size28 = 28;
  static const double size31 = 31;
  static const double size32 = 32;
  static const double size34 = 34;
  static const double size36 = 36;
}

/// ارتفاعات الأسطر المستخدمة في أنماط النصوص.
///
/// الرقم في الاسم هو قيمة الارتفاع نفسها.
abstract final class AppTextHeights {
  static const double line1 = 1;
  static const double line1_1 = 1.1;
  static const double line1_15 = 1.15;
  static const double line1_2 = 1.2;
  static const double line1_3 = 1.3;
  static const double line1_35 = 1.35;
  static const double line1_4 = 1.4;
  static const double line1_45 = 1.45;
  static const double line1_5 = 1.5;
  static const double line1_55 = 1.55;
  static const double line1_6 = 1.6;
  static const double line1_7 = 1.7;
  static const double line1_8 = 1.8;
}

/// تباعد الحروف المستخدم في أنماط النصوص.
abstract final class AppLetterSpacings {
  static const double space0_2 = 0.2;
  static const double space0_4 = 0.4;
  static const double space0_8 = 0.8;
  static const double space1_1 = 1.1;
  static const double spaceNegative0_5 = -0.5;
  static const double spaceNegative0_8 = -0.8;
}

/// أنماط النصوص الجاهزة: الوزن والحجم من [AppFontWeights] و[AppFontSizes] فقط.
class AppFonts {
  const AppFonts._();

  static TextStyle base(BuildContext context) =>
      TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color);

  static TextStyle _style(
    BuildContext context,
    FontWeight weight,
    double size,
  ) =>
      base(context)
          .copyWith(fontWeight: weight, fontSize: size.clamp(1.0, 1000.0));

  // ===== Regular =====
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

  // ===== Medium =====
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

  // ===== SemiBold =====
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

  // ===== Bold =====
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
  static TextStyle bold36(BuildContext context) =>
      _style(context, AppFontWeights.bold, AppFontSizes.size36);
}
