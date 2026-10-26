import 'package:flutter/material.dart';

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
        : const Color(0xFF718078);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${orderCount(count)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? (dark
                        ? AppColor.adminAccent.withValues(alpha: .18)
                        : AppColor.adminAccentSurface)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? AppColor.adminAccent.withValues(alpha: .22)
                          : const Color(0xFFD5E8DD),
                      borderRadius: BorderRadius.circular(5),
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
                  const SizedBox(width: 5),
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
