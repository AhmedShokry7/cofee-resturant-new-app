import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/typography.dart';

/// سطر جملة يبرز فيها رقم: مقدّمة، ثم القيمة بلونها، ثم تتمة الكلام.
///
/// النسبة تُطبع داخل الكلام لا فوقه حين كان الكلام هو الخبر — «مبيعاتك ارتفعت
/// ١٨٪ عن الشهر الماضي» تُقرأ جملة، وتلوين الرقم وحده يمنع اللوحة أن تصير
/// جدولًا من الشارات. والقطع ثلاث نصية، فلا يفرض أحد الاتجاه على ترتيبها.
class AdminHighlightLine extends StatelessWidget {
  const AdminHighlightLine({
    super.key,
    required this.before,
    required this.value,
    required this.after,
    required this.style,
    required this.valueColor,
    this.maxLines = 2,
  });

  final String before;

  /// الرقم المبرز، ويُرسل منسوكًا كما اختارته الصفحة.
  final String value;

  final String after;

  /// طابع الجملة كله؛ الغامق واللون يخصّان الرقم وحده.
  final TextStyle style;

  final Color valueColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: before.isEmpty ? '' : '$before ',
      children: [
        TextSpan(
          text: value,
          style: TextStyle(color: valueColor, fontWeight: AppFontWeights.bold),
        ),
        if (after.isNotEmpty) TextSpan(text: ' $after'),
      ],
    ),
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
}
