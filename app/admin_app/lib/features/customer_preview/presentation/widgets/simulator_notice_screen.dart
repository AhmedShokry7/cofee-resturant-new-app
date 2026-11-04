import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_palette.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// شاشة داخل الهاتف لا تملك اللوحة بياناتها: السلة والمفضلة والإعدادات.
///
/// تطبيق العميل يملؤها من حساب الزبون على جهازه، واللوحة لا تقرأ حساب زبون
/// بعينه. تُطبع الحقيقة في سطر بدل أن تُلفَّق صفوف لا مصدر لها.
class SimulatorNoticeScreen extends StatelessWidget {
  const SimulatorNoticeScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.note,
  });

  final IconData icon;
  final String title;
  final String note;

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
            const SizedBox(height: AppSpacing.xs),
            Text(
              note,
              textAlign: TextAlign.center,
              style: AppFonts.regular14(context)
                  .copyWith(color: palette.textSecondary ?? adminMutedColor(theme)),
            ),
          ],
        ),
      ),
    );
  }
}
