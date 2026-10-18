import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppFonts {
  static TextStyle base(BuildContext context) =>
      TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color);

  // ✅ دالة لضبط حجم الخط حسب نوع الجهاز
  static double _responsiveFontSize(double fontSize, BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;

    if (shortestSide >= 600) {
      // تابلت → نقلل حجم الخط بنسبة بسيطة
      return fontSize * 0.8;
    } else {
      // موبايل → الحجم الطبيعي
      return fontSize;
    }
  }

  static TextStyle _style(
    BuildContext context,
    FontWeight weight,
    double size,
  ) => base(context).copyWith(
    fontWeight: weight,
    fontSize: _responsiveFontSize(size, context).sp.clamp(1.0, 1000.0),
  );

  // ===== Regular (400) =====
  static TextStyle regular12(BuildContext context) =>
      _style(context, FontWeight.w400, 12);
  static TextStyle regular14(BuildContext context) =>
      _style(context, FontWeight.w400, 14);
  static TextStyle regular16(BuildContext context) =>
      _style(context, FontWeight.w400, 16);
  static TextStyle regular18(BuildContext context) =>
      _style(context, FontWeight.w400, 18);
  static TextStyle regular20(BuildContext context) =>
      _style(context, FontWeight.w400, 20);
  static TextStyle regular24(BuildContext context) =>
      _style(context, FontWeight.w400, 24);
  static TextStyle regular28(BuildContext context) =>
      _style(context, FontWeight.w400, 28);
  static TextStyle regular32(BuildContext context) =>
      _style(context, FontWeight.w400, 32);

  // ===== Medium (500) =====
  static TextStyle medium12(BuildContext context) =>
      _style(context, FontWeight.w500, 12);
  static TextStyle medium14(BuildContext context) =>
      _style(context, FontWeight.w500, 14);
  static TextStyle medium16(BuildContext context) =>
      _style(context, FontWeight.w500, 16);
  static TextStyle medium18(BuildContext context) =>
      _style(context, FontWeight.w500, 18);
  static TextStyle medium20(BuildContext context) =>
      _style(context, FontWeight.w500, 20);
  static TextStyle medium24(BuildContext context) =>
      _style(context, FontWeight.w500, 24);
  static TextStyle medium28(BuildContext context) =>
      _style(context, FontWeight.w500, 28);
  static TextStyle medium32(BuildContext context) =>
      _style(context, FontWeight.w500, 32);

  // ===== SemiBold (600) =====
  static TextStyle semiBold12(BuildContext context) =>
      _style(context, FontWeight.w600, 12);
  static TextStyle semiBold14(BuildContext context) =>
      _style(context, FontWeight.w600, 14);
  static TextStyle semiBold16(BuildContext context) =>
      _style(context, FontWeight.w600, 16);
  static TextStyle semiBold18(BuildContext context) =>
      _style(context, FontWeight.w600, 18);
  static TextStyle semiBold20(BuildContext context) =>
      _style(context, FontWeight.w600, 20);
  static TextStyle semiBold24(BuildContext context) =>
      _style(context, FontWeight.w600, 24);
  static TextStyle semiBold28(BuildContext context) =>
      _style(context, FontWeight.w600, 28);
  static TextStyle semiBold32(BuildContext context) =>
      _style(context, FontWeight.w600, 32);

  // ===== Bold (700) =====
  static TextStyle bold12(BuildContext context) =>
      _style(context, FontWeight.w700, 12);
  static TextStyle bold14(BuildContext context) =>
      _style(context, FontWeight.w700, 14);
  static TextStyle bold16(BuildContext context) =>
      _style(context, FontWeight.w700, 16);
  static TextStyle bold18(BuildContext context) =>
      _style(context, FontWeight.w700, 18);
  static TextStyle bold20(BuildContext context) =>
      _style(context, FontWeight.w700, 20);
  static TextStyle bold24(BuildContext context) =>
      _style(context, FontWeight.w700, 24);
  static TextStyle bold28(BuildContext context) =>
      _style(context, FontWeight.w700, 28);
  static TextStyle bold32(BuildContext context) =>
      _style(context, FontWeight.w700, 32);
}
