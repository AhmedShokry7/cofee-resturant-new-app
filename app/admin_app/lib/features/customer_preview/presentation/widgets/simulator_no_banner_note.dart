import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// سطر ملاحظة للموظف مكان مقطع البنر الفارغ.
///
/// التطبيق عند الزبون يخفي المقطع كله حين لا بانر نافذًا، واللوحة تحتاج أن تعرف
/// أن الخفاء قرار في التوقيت لا خلل في القراءة، لذلك تبقى الملاحظة هنا وحدها
/// ولا تُنقل إلى شاشة الزبون.
class SimulatorNoBannerNote extends StatelessWidget {
  const SimulatorNoBannerNote({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          AppIcon(
            AppIcons.informationCircle,
            size: AppSizes.px16,
            color: adminMutedColor(theme),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppFonts.regular12(context)
                  .copyWith(color: adminMutedColor(theme)),
            ),
          ),
        ],
      ),
    );
  }
}
