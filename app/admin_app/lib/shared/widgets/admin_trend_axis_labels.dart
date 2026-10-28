import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_trend_point.dart';

/// تسميات المحور الأفقي، بقدر ما يسعه العرض لا بقدر ما تُخيّل الصفحة.
///
/// سبع تسميات تملأ عرض مكتب وتتكسر إلى حروف على هاتف؛ فالمقياس عرض التسمية
/// لا عددًا ثابتًا، وتُختار النقاط بالتساوي بين الأقدم والأحدث كي يبقى آخرها
/// تاريخ اليوم نفسه.
class AdminTrendAxisLabels extends StatelessWidget {
  const AdminTrendAxisLabels({
    super.key,
    required this.points,
    required this.labelCount,
  });

  final List<AdminTrendPoint> points;

  /// أقصى ما تُطلب من تسميات؛ يُنقصه العرض حين يزدحم.
  final int labelCount;

  /// أقل عرض تسمية يقرأ «٢٨ أكتوبر» دون أن تُقطع.
  static const _minLabelWidth = 64.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = (constraints.maxWidth / _minLabelWidth).floor();
        final count = math
            .min(labelCount, fits)
            .clamp(2, points.length)
            .toInt();
        final last = points.length - 1;
        return Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Text(
                  points[(i * last / (count - 1)).round()].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
