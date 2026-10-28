import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// نقطة بلونها واسمها: مفتاح رسم لا أكثر.
///
/// الاسم وحده يشرح النقطة، فلا تُكتب درجة لونية أمام الأدمن لا يقارنها بشيء.
/// ويُستعمل تحت كل رسم بياني في اللوحة كي لا تركّب كل بطاقة مفتاحها بحشوها.
class AdminChartLegend extends StatelessWidget {
  const AdminChartLegend({
    super.key,
    required this.label,
    required this.color,
    this.trailing,
  });

  final String label;
  final Color color;

  /// سطر ثانٍ اختيار عند النقطة، مثل نسبة الجزء من كله.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: AppSizes.px8,
          height: AppSizes.px8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSizes.px6),
        Text(
          label,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size8,
            height: AppTextHeights.line1_4,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSizes.px6),
          trailing!,
        ],
      ],
    );
  }
}
