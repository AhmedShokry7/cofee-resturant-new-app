import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';

/// A single navigation row inside the dark panel.
class AdminSidebarItem extends StatelessWidget {
  const AdminSidebarItem({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
  });

  final AdminDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  /// Live work waiting in this destination, shown as a number.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = isSelected
        ? AppColor.secondaryColor
        : AppColor.whiteColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? AppColor.sidebarActiveBackground
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.lg,
              vertical: AppDimensions.md,
            ),
            child: Row(
              children: [
                Icon(destination.icon, size: 18, color: foreground),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: isSelected
                          ? AppFontWeights.semiBold
                          : AppFontWeights.regular,
                    ),
                  ),
                ),
                if ((badgeCount ?? 0) > 0)
                  _SidebarBadge(label: _countLabel(badgeCount!)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _countLabel(int count) =>
      localizeDigits(count > 99 ? '99+' : '$count');
}

class _SidebarBadge extends StatelessWidget {
  const _SidebarBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColor.secondaryColor,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColor.primaryColor,
          fontWeight: AppFontWeights.medium,
        ),
      ),
    );
  }
}

/// The muted heading that groups navigation rows.
class AdminSidebarSectionTitle extends StatelessWidget {
  const AdminSidebarSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.xs,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColor.secondaryColor,
          fontSize: AppFontSizes.size15,
        ),
      ),
    );
  }
}
