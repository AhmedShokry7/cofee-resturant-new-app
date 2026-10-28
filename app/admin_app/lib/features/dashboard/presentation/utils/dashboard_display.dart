import 'package:flutter/cupertino.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_top_product.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_setup_step.dart';

/// اسم المنتج باللغة المعروضة، وبالأخرى حين تُترك تلك خالية في الكتالوج.
///
/// الاسم يصل من القاعدة بالعنوانين، فالعرض وحده يقرّر أيهما يقرأ الأدمن؛ الكيان
/// لا يستورد شيئًا من الواجهة لأن الكيان يبقى بلا واجهة. ومنتج سُمّي بلغة واحدة
/// يُطبع باسمه الوحيد بدل سطر فارغ أمام سعره.
String dashboardProductName(AdminDashboardTopProduct product) {
  final chosen = AppLocale.instance.isArabic ? product.nameAr : product.nameEn;
  final other = AppLocale.instance.isArabic ? product.nameEn : product.nameAr;
  return chosen.trim().isEmpty ? other : chosen;
}

/// تسمية محور المنحنى: رقم اليوم واسم شهره.
///
/// المحور يعرض خمس تسميات أو سبعًا، ورقم اليوم وحده يُقرأ غامضًا حين تتقاطع
/// النافذة مع رأس شهر؛ التاريخ الكامل يبقى في السجل نفسه حين يحتاجه الأدمن.
String dashboardDayLabel(DateTime date) =>
    localizeDigits('${date.day} ${localizedMonthName(date.month)}');

/// تسمية المحور الرأسي: ألف مقروءة بدل ستة أصفار.
///
/// عرض اللوحة يرفض رقمًا بخمس خانات على عمود ضيّق، والأدمن يقارن ارتفاعات لا
/// يقرأ أرقامًا على المحور؛ القيمة الدقيقة تُطبع فوق المنحنى لا على جنبه.
String dashboardAxisValue(double value) {
  if (value < 1000) return localizeDigits('${value.round()}');
  final thousands = (value / 1000).round();
  return AppLocale.instance.isArabic
      ? '${localizeDigits('$thousands')} ألف'
      : '${localizeDigits('$thousands')}k';
}

/// لون قناة بثبات حسب ترتيبها، من لوحة الحروف المشتركة.
///
/// القنوات ثلاث أو أقل، واللوحة ستة أزواج، فيبقى لكل قناة لونُها ما دام
/// ترتيبها ما دام الجمع في القاعدة يرتّبها بالحجم نفسه.
Color dashboardChannelColor(int index) =>
    AppColor.initialTints[index % AppColor.initialTints.length].$2;

/// اسم خطوة البداية من مفتاحها الذي ترسله القاعدة.
///
/// المفتاح كلمة ثابتة في ترحيلة ٢٠٤ والنصّ هنا، فتُترجم الخطوة وتُعدَّل بلا
/// ترحيلة؛ ومفتاح لا تعرفه اللوحة يُترك بلا سطر لا أن يُطبع رمزه الخام أمام
/// الأدمن، لأن شيفرة داخل جملة عربية تُقرأ خللًا في المتجر لا في العرض.
String? dashboardSetupLabel(String key) => switch (key) {
  'first_product' => S.dashboardSetupFirstProduct,
  'branch_image' => S.dashboardSetupBranchImage,
  'revenue_target' => S.dashboardSetupRevenueTarget,
  'first_order' => S.dashboardSetupFirstOrder,
  _ => null,
};

/// خطوات البداية التي للوحة اسمٌ لها، بترتيب القاعدة.
///
/// خطوة لا اسم عندها لا تُعرض ولا تُعَدّ في «المُنجَز من الكل»: عدّادٌ يقول «٢/٤»
/// تحت ثلاثة أسطر يُقرأ كذبًا، وسطرٌ برمز خام أمام الأدمن يُقرأ خللًا في المتجر.
List<DashboardSetupStep> dashboardVisibleSetupSteps(
  AdminDashboardMetrics metrics,
) => [
  for (final step in metrics.setupSteps)
    if (dashboardSetupLabel(step.key) != null) step,
];

/// نصيب أعمدة جدول أحدث الطلبات من العرض، بترتيب رؤوسه.
///
/// الرأس والأسطر يقرآن القائمة نفسها: عمودٌ يُقاس في مكانين يختلف مقاسه بينهما،
/// فتُقرأ الخانة تحت رأس غير رأسها. وترتيبها ترتيب القراءة العربية: رقم الطلب
/// أوّلها وأدناها، والحالة آخرها حيث تُلتقط العين.
const dashboardOrderColumnFlexes = <int>[4, 4, 4, 3, 5];

/// مدى المبيعات الذي تدور عليه اللوحة: أسبوع أو شهر.
///
/// رقمٌ واحد في مكانين يختلف معناه: «آخر ٣٠» تحت المنحنى و«مقارنة بالشهر
/// الماضي» في شريط النمو قراران يقرآن مدىً واحدًا، فيُسمّى مرة واحدة.
const dashboardWeekRangeDays = 7;
const dashboardMonthRangeDays = 30;
