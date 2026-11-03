import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// أزمنة الحركة التي يقلدها المحاكي من تطبيق العميل.
///
/// أرقام طبقة العرض عند العميل، لا أرقام لوحة التحكم: الغرض أن يتحرك الهاتف
/// داخل الإطار كما يتحرك في جيب الزبون، فالموظف الذي يراجع بنرًا يقرأ مدة
/// وقوفه على الشاشة لا مدة وقوفه في اللوحة.
abstract final class SimulatorMotion {
  SimulatorMotion._();

  /// كم يثبت البنر قبل أن ينتقل تلقائيًا إلى التالي.
  static const Duration carouselHold = Duration(seconds: 5);

  /// مدة انزلاق الصفحة تحت الإصبع أو تحت المؤقت.
  static const Duration pageSlide = Duration(milliseconds: 280);

  /// مدة تغيّر شكل نقطة البنرات: تسبق وصول الصفحة حتى لا يبدو الاثنان متخالفين.
  static const Duration dotMorph = Duration(milliseconds: 220);

  /// كم يبقى صف التصنيفات واقفًا بعد أن يرفع الموظف إصبعه قبل أن يمشي.
  static const Duration marqueeResume = Duration(milliseconds: 2500);

  /// المنحنى الذي يمشي مع [pageSlide]: يبدأ فورًا ويستقر.
  static const Curve entranceCurve = Curves.easeOutCubic;
}

/// ظل البلاطة الدائرية كما يرسمه العميل.
abstract final class SimulatorShadows {
  SimulatorShadows._();

  static const List<BoxShadow> tile = [
    BoxShadow(
      color: AppColor.shadowMedium,
      blurRadius: AppSizes.px4,
      offset: Offset(0, AppSizes.px4),
    ),
  ];
}
