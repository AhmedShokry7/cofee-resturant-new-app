import 'package:flutter/material.dart';

import 'package:admin_app/shared/widgets/admin_metric_card.dart';

/// بلاطة رقم واحد، بنسبتها إلى أساسها لا بنسبة تُخترع.
///
/// النسبة تُقاس بين رقمين وصلًا معًا من القاعدة: إن غاب الأساس تُترك الشارة
/// صامتة وتبقى البلاطة وحدها، لأن «+٠٪» أمام رقم جديد تُقرأ أن المتجر لم ينمُ
/// وهو لم يبدأ بعد. والمرجع مكتوب تحتها: شارةٌ بلا أساس تترك الأدمن يخمّن من
/// أي نقطة قُيست.
class DashboardMetricTile extends StatelessWidget {
  const DashboardMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.surface,
    required this.ink,
    required this.current,
    required this.previous,
    required this.caption,
    this.isMoney = false,
    this.captionIsMoney = false,
  });

  final String label;
  final String value;
  final IconData icon;

  /// لون الحقل الذي يسكنه الرمز، وشارة الاسم عليه — من لوحة الحروف المشتركة.
  final Color surface;
  final Color ink;

  /// الرقم هذا المدى، والأساس الذي يُقارَن به؛ أساسٌ صفر لا نسبة معه.
  final num current;
  final num previous;
  final String caption;

  /// بلاطة مال: رقم بلا رمز عملة يُطبع معه، فالعملة علامة تُرى لا كلمة تُقرأ.
  final bool isMoney;
  final bool captionIsMoney;

  @override
  Widget build(BuildContext context) {
    final trend = metricPercentTrend(current, previous);
    return AdminMetricCard(
      label: label,
      value: value,
      icon: icon,
      iconBackground: surface,
      iconColor: ink,
      changeLabel: trend?.label,
      isPositive: trend?.positive ?? true,
      caption: caption,
      isMoney: isMoney,
      captionIsMoney: captionIsMoney,
    );
  }
}
