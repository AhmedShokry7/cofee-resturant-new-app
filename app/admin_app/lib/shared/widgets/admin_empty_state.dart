import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';

/// The quiet icon and message an admin list shows when it has nothing to list.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.action,
  });

  final IconData icon;
  final String message;

  /// A quieter second line that explains what the empty list is for.
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 38, color: muted.withValues(alpha: .6)),
            const SizedBox(height: AppSizes.px10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: AppFontSizes.size12,
                height: AppTextHeights.line1_5,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: AppSizes.px4),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted.withValues(alpha: .8),
                  fontSize: AppFontSizes.size10,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSizes.px4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
