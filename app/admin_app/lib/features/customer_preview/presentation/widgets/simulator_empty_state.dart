import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_palette.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// حالة فارغة داخل شاشة العميل، بنفس ترتيب حالة العميل: أيقونة ثم عنوان ثم سطر.
///
/// تُعرض بدل أي بيانات مخترعة: لا سلة ولا مفضلة ولا تصنيف يظهر ما لا تقرؤه
/// اللوحة من القاعدة.
class SimulatorEmptyState extends StatelessWidget {
  const SimulatorEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SimulatorPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              icon,
              size: AppSizes.px48,
              color: palette.textSecondary ?? adminSubtleColor(theme),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppFonts.semiBold16(context)
                  .copyWith(color: palette.textPrimary ?? adminHeadingColor(theme)),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppFonts.regular14(context)
                    .copyWith(color: palette.textSecondary ?? adminMutedColor(theme)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
