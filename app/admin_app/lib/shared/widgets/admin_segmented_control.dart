import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// مفتاح تبديل مصغّر يختار خيارًا واحدًا من قائمة نصية قصيرة،
/// ويُظهر الخيار النشط على بطاقة فاتحة داخل مسار ملوّن.
class AdminSegmentedControl extends StatelessWidget {
  const AdminSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// الخيارات النصية بترتيب العرض.
  final List<String> options;

  /// الخيار النشط حاليًا، ويجب أن يكون أحد [options].
  final String selected;

  /// تُستدعى فقط عند اختيار خيار مختلف عن [selected].
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.pill);
    return Material(
      color: adminTintedSurfaceColor(theme),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: AppSizes.px30,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.px2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in options) _segment(theme, option, radius),
            ],
          ),
        ),
      ),
    );
  }

  /// يبني قطعة واحدة قابلة للنقر والتركيز مع حالة اختيارها.
  Widget _segment(ThemeData theme, String option, BorderRadius radius) {
    final isSelected = option == selected;
    return Semantics(
      button: true,
      selected: isSelected,
      child: Ink(
        decoration: BoxDecoration(
          color: isSelected
              ? (adminIsDark(theme) ? AppColor.darkCard : AppColor.whiteColor)
              : AppColor.transparent,
          borderRadius: radius,
        ),
        child: InkWell(
          onTap: () {
            if (!isSelected) onChanged(option);
          },
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Center(
              child: Text(
                option,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected
                      ? AppColor.adminAccent
                      : adminMutedColor(theme),
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: isSelected
                      ? AppFontWeights.semiBold
                      : AppFontWeights.medium,
                  height: AppTextHeights.line1_3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
