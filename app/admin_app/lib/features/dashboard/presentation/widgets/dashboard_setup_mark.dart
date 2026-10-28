import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// المكتملة تُطبع بعلامة صحّ داخل دائرة مخضّرة، والمنتظرة برقمها في دائرة مرسومة.
///
/// الدائرة المرسومة بلا لون ولا يد: الخطوة تُقرأ من القاعدة ولا تُنقر من هنا،
/// فلا زرّ في اللوحة يوحي بأن اكتمالها بيد الأدمن وهو لا يملكه.
class DashboardSetupMark extends StatelessWidget {
  const DashboardSetupMark({
    super.key,
    required this.done,
    required this.position,
  });

  final bool done;
  final int position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: AppSizes.px20,
      height: AppSizes.px20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done
            ? adminFlagBackground(
                theme,
                AppColor.trendPositive,
                AppColor.tintGreenSurface,
              )
            : null,
        shape: BoxShape.circle,
        border: done ? null : Border.all(color: adminControlBorderColor(theme)),
      ),
      child: done
          ? AppIcon(
              AppIcons.checkmarkCircle02,
              size: AppSizes.px14,
              color: adminFlagForeground(theme, AppColor.trendPositive),
            )
          : Text(
              localizeDigits('$position'),
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size8,
                height: AppTextHeights.line1,
              ),
            ),
    );
  }
}
