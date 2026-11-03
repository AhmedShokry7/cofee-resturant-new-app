import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// شريط حالة الهاتف: ساعة الجهاز فقط.
///
/// أيقونات الشبكة والبطارية لا تُرسم هنا: لا مصدر لها في التطبيق، ورسمها يكون
/// زينة تدّعي حالة لا تعرفها اللوحة.
class SimulatorStatusBar extends StatelessWidget {
  const SimulatorStatusBar({super.key, required this.timeLabel});

  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: AppDimensions.simulatorStatusBarHeight,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Text(
        timeLabel,
        style: AppFonts.medium12(context)
            .copyWith(color: adminMutedColor(theme)),
      ),
    );
  }
}
