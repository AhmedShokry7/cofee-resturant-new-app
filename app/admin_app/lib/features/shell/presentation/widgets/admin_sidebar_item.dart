import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';

/// A single navigation row inside the dark panel.
class AdminSidebarItem extends StatelessWidget {
  const AdminSidebarItem({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final AdminDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

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
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (destination.badge != null)
                  _SidebarBadge(label: destination.badge!),
                if (!destination.isImplemented)
                  _SidebarBadge(label: S.soonBadge, muted: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarBadge extends StatelessWidget {
  const _SidebarBadge({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted
            ? AppColor.whiteColor.withValues(alpha: 0.12)
            : AppColor.secondaryColor,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: muted ? AppColor.whiteColor : AppColor.primaryColor,
          fontWeight: FontWeight.w500,
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
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColor.secondaryColor, fontSize: 15),
      ),
    );
  }
}
