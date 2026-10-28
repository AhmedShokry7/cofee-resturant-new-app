import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/core/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_dropdown.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderPaymentStatusControl extends StatelessWidget {
  const OrderPaymentStatusControl({
    super.key,
    required this.order,
    required this.saving,
    this.onChanged,
  });

  final AdminOrder order;
  final bool saving;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final view = OrderPaymentStatusView.of(order.paymentStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.paymentStatusLabelTitle,
                style: TextStyle(
                  color: adminMutedColor(theme),
                  fontSize: AppFontSizes.size10_5,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ),
            _PaymentPill(label: view.label, color: view.color),
          ],
        ),
        if (onChanged != null) ...[
          const SizedBox(height: AppSizes.px10),
          OrderFilterDropdown(
            key: ValueKey(order.paymentStatus),
            label: S.changePaymentStatus,
            value: OrderPaymentStatusView.allCodes.contains(order.paymentStatus)
                ? order.paymentStatus
                : '',
            items: [
              for (final code in OrderPaymentStatusView.allCodes)
                DropdownMenuItem(
                  value: code,
                  child: Text(OrderPaymentStatusView.of(code).label),
                ),
            ],
            enabled: !saving,
            onChanged: onChanged!,
          ),
          if (saving)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColor.adminAccent,
                backgroundColor: AppColor.adminAccentSurface,
              ),
            ),
        ],
      ],
    );
  }
}

class _PaymentPill extends StatelessWidget {
  const _PaymentPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    final foreground = adminFlagForeground(theme, color);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: dark
            ? color.withValues(alpha: .16)
            : Color.lerp(color, AppColor.whiteColor, .86),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: dark ? .35 : .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: AppFontSizes.size9_5,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.px6),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: foreground,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
        ],
      ),
    );
  }
}
