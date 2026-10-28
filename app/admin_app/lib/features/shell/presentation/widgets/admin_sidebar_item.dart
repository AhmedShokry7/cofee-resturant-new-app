import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';

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

  /// Unread work waiting in this destination, shown as a number.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = isSelected
        ? AppColor.secondaryColor
        : AppColor.whiteColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Material(
        color: isSelected
            ? AppColor.sidebarActiveBackground
            : AppColor.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(destination.icon, size: 18, color: foreground),
                const SizedBox(width: AppSpacing.md),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColor.errorColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColor.whiteColor,
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
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
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
