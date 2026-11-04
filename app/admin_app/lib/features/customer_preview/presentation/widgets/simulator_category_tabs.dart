import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_palette.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// شريط أسماء التصنيفات أعلى شاشة التصنيفات، كما في تطبيق العميل: الاسم المختار
/// أخضر وتحته خط، وغيره باهت بلا خط.
class SimulatorCategoryTabs extends StatelessWidget {
  const SimulatorCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.language,
    required this.onSelect,
  });

  final List<AdminCategory> categories;

  /// التصنيف الموقد الآن، أو null حين لم يختر العميل واحدًا بعد.
  final String? selectedId;
  final AppLanguage language;
  final ValueChanged<AdminCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SimulatorPalette.of(context);
    return Container(
      height: AppDimensions.simulatorTabBarHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.border ?? adminCardBorderColor(theme)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.id == selectedId;
          return Semantics(
            button: true,
            selected: isSelected,
            label: category.nameFor(language),
            child: Material(
              color: AppColor.transparent,
              child: InkWell(
                onTap: () => onSelect(category),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Text(
                              category.nameFor(language),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.medium16(context).copyWith(
                                color: isSelected
                                    ? palette.primary
                                    : palette.textSecondary ?? adminMutedColor(theme),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: AppDimensions.simulatorTabIndicatorHeight,
                        decoration: BoxDecoration(
                          color: isSelected ? palette.primary : AppColor.transparent,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
