import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_palette.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// رأس صفحة العميل: تحية على قدر الساعة، وسؤال الصفحة تحتها، وعلامة النهار
/// أو الليل إلى جوار التحية.
///
/// اسم الزبون جوار التحية لا يُطبع: اللوحة لا تقرأ حساب زبون بعينه، فجدار
/// الصلاحيات يتركه لصاحبه. جرس التنبيهات لا يُرسم هو الآخر لنفس السبب، والسببان
/// تقرأهما السكة الجانبية بدل أن يُتركا فجوة صامتة في المقارنة.
class SimulatorHomeHeader extends StatelessWidget {
  const SimulatorHomeHeader({
    super.key,
    required this.labels,
    required this.now,
  });

  final SimulatorLabels labels;
  final DateTime now;

  /// النهار من السادسة صباحًا إلى الخامسة مساءً، وهي قاعدة العميل نفسها.
  static bool isDaytime(DateTime time) => time.hour >= 6 && time.hour < 17;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SimulatorPalette.of(context);
    final daytime = isDaytime(now);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      labels.greeting(now),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.regular14(context).copyWith(
                        color: palette.textSecondary ?? adminMutedColor(theme),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AppIcon(
                    daytime ? AppIcons.sun03 : AppIcons.moon01,
                    size: AppSizes.px30,
                    color: palette.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                labels.homeQuestion,
                style: AppFonts.semiBold20(context).copyWith(
                  color: palette.textPrimary ?? adminHeadingColor(theme),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
