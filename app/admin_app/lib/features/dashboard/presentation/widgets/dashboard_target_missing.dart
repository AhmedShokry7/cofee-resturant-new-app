import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// البطاقة بلا هدف: تُقال الحقيقة ويسأل صاحبُها أن يكتبها.
///
/// صفرٌ على مقياس لم يُضعه أحد كذب، وشريط تقدّم عند صفر يوحي أن الهدف معروف
/// والمتجر متأخر — وهو لا هذا ولا ذاك.
class DashboardTargetMissing extends StatelessWidget {
  const DashboardTargetMissing({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.px16),
      child: Column(
        children: [
          Text(
            S.dashboardTargetEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(height: AppSizes.px4),
          Text(
            S.dashboardTargetEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ),
    );
  }
}
