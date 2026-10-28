import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_setup_step.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_setup_mark.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// سطر خطوة واحدة من خطوات البداية: اسمها، وحالتها، وموضعها إن لم تُقضَ.
///
/// الحالة كلمة مكتوبة لا لون وحده، لأن شارة خضراء وحدها تُقرأ بصعوبة في نصّ
/// عربي بلا شكل. ومفتاح الخطوة يصل من القاعدة بكلمة إنجليزية، فاللوحة تعرف
/// الأربع وتترك ما لا تعرفه بلا سطر لا برمز خام أمام الأدمن.
class DashboardSetupRow extends StatelessWidget {
  const DashboardSetupRow({
    super.key,
    required this.step,
    required this.position,
  });

  final DashboardSetupStep step;

  /// ترتيب الخطوة كما وصلت من القاعدة، ويُطبع على المنتظرة منها فقط.
  final int position;

  @override
  Widget build(BuildContext context) {
    final label = dashboardSetupLabel(step.key)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.px8),
      child: Row(
        children: [
          SizedBox(
            width: AppSizes.px38,
            child: step.done
                ? Text(
                    S.dashboardSetupDone,
                    maxLines: 1,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size8,
                      height: AppTextHeights.line1_4,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSizes.px8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminHeadingColor(theme),
                fontSize: AppFontSizes.size9,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_4,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          DashboardSetupMark(done: step.done, position: position),
        ],
      ),
    );
  }
}
