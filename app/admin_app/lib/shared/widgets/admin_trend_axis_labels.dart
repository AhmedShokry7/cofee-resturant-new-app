import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_trend_point.dart';

/// تسميات المحور الأفقي، بقدر ما يسعه العرض لا بقدر ما تُخيّل الصفحة.
///
/// إذا سع العرض لتسمية كل يوم نزلت تسمية قصيرة لكل نقطة، وإلا تنكسر إلى
/// حروف أو تُختار النقاط بالتساوي بين الأقدم والأحدث كي يبقى آخرها
/// تاريخ اليوم نفسه. واليوم المشارة إليه بالمؤشر يُطبع بالحبر النشط.
class AdminTrendAxisLabels extends StatelessWidget {
  const AdminTrendAxisLabels({
    super.key,
    required this.points,
    required this.labelCount,
    this.highlightIndex,
  });

  final List<AdminTrendPoint> points;

  /// أقصى ما تُطلب من تسميات؛ يُنقصه العرض حين يزدحم.
  final int labelCount;

  /// النقطة المشار إليها بالمؤشر، فتُبرز تسميتها على بقية الصف.
  final int? highlightIndex;

  /// أقل عرض تسمية يقرأ «٢٨ أكتوبر» دون أن تُقطع.
  static const _minLabelWidth = 64.0;

  /// أقل عرض يقرأ رقم اليوم وحده دون أن يتكسر.
  static const _minDayWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final last = points.length - 1;
        final hover = highlightIndex;
        if (points.length > 2 && width / points.length >= _minDayWidth) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                for (var i = 0; i < points.length; i++)
                  Expanded(
                    child: Text(
                      points[i].shortLabel ?? points[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: i == hover
                            ? AppColor.primaryColor
                            : adminMutedColor(theme),
                        fontWeight: i == hover
                            ? AppFontWeights.bold
                            : AppFontWeights.regular,
                        fontSize: AppFontSizes.size8,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        final fits = (width / _minLabelWidth).floor();
        final count = math
            .min(labelCount, fits)
            .clamp(2, points.length)
            .toInt();
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final shown = (i * last / (count - 1)).round();
                      return Text(
                        points[shown].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: shown == hover
                              ? AppColor.primaryColor
                              : adminMutedColor(theme),
                          fontWeight: shown == hover
                              ? AppFontWeights.bold
                              : AppFontWeights.regular,
                          fontSize: AppFontSizes.size9,
                          height: AppTextHeights.line1_4,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
