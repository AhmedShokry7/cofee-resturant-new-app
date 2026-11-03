import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/domain/entities/simulator_tab.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/simulator_labels.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// شريط التنقل السفلي داخل الهاتف، بنفس ترتيب تبويبات تطبيق العميل الخمسة.
///
/// التبديل بينها ينقل الموظف إلى شاشة ذلك التبويب فعلًا، فلا أيقونة هنا توحي
/// بسلوك لا يحدث.
class SimulatorBottomBar extends StatelessWidget {
  const SimulatorBottomBar({
    super.key,
    required this.tab,
    required this.labels,
    required this.onSelect,
  });

  final SimulatorTab tab;
  final SimulatorLabels labels;
  final ValueChanged<SimulatorTab> onSelect;

  static const List<SimulatorTab> _order = SimulatorTab.values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: AppDimensions.simulatorBottomBarHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: adminCardBorderColor(theme))),
      ),
      child: Row(
        children: [
          for (final entry in _order)
            Expanded(
              child: _TabItem(
                icon: _iconOf(entry),
                label: labels.tabLabel(entry),
                selected: entry == tab,
                onTap: () => onSelect(entry),
              ),
            ),
        ],
      ),
    );
  }

  /// الأيقونات المقابلة لتبويبات العميل: بيت، شبكة التصنيفات، السلة، المفضلة،
  /// الإعدادات.
  static IconData _iconOf(SimulatorTab tab) {
    switch (tab) {
      case SimulatorTab.home:
        return AppIcons.home01;
      case SimulatorTab.categories:
        return AppIcons.dashboardSquare01;
      case SimulatorTab.cart:
        return AppIcons.shoppingCart01;
      case SimulatorTab.favourites:
        return AppIcons.star;
      case SimulatorTab.settings:
        return AppIcons.settings01;
    }
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? AppColor.primaryColor : adminMutedColor(theme);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: AppColor.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: AppSizes.px24, color: color),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.medium12(context).copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
