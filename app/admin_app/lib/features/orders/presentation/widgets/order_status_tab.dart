import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';

class OrderStatusTab extends StatelessWidget {
  const OrderStatusTab({
    super.key,
    required this.code,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String code, label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = selected
        ? AppColor.adminAccent
        : dark
        ? AppColor.darkTextSecondary
        : AppColor.statusTabIdleInk;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${orderCount(count)}',
      child: Material(
        color: AppColor.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? (dark
                        ? AppColor.adminAccent.withValues(alpha: .18)
                        : AppColor.adminAccentSurface)
                  : AppColor.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? AppColor.adminAccent.withValues(alpha: .22)
                          : AppColor.statusTabIdleSurface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      orderCount(count),
                      style: const TextStyle(
                        color: AppColor.adminAccent,
                        fontSize: AppFontSizes.size9,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.px6),
                ],
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: AppFontSizes.size10,
                    fontWeight: selected
                        ? AppFontWeights.semiBold
                        : AppFontWeights.regular,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
