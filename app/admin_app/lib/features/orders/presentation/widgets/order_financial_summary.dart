import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_format.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

class OrderFinancialSummary extends StatelessWidget {
  const OrderFinancialSummary({
    super.key,
    required this.order,
    this.paymentMethodLabel,
  });

  final AdminOrder order;
  final String? paymentMethodLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (paymentMethodLabel?.trim().isNotEmpty == true)
          _textRow(context, S.paymentMethod, paymentMethodLabel!),
        _amountRow(context, S.subtotal, order.subtotal),
        if (order.discountTotal > 0)
          _amountRow(context, S.discount, -order.discountTotal),
        if (order.fulfillmentType == 'delivery')
          _amountRow(context, S.deliveryFee, order.deliveryFee),
        if (order.taxTotal > 0) _amountRow(context, S.tax, order.taxTotal),
        const SizedBox(height: AppSizes.px10),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: adminFlagBackground(
              theme,
              AppColor.adminAccent,
              AppColor.adminAccentSurface,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColor.adminAccent.withValues(
                alpha: adminIsDark(theme) ? .35 : .18,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  S.grandTotal,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              AdminMoneyText(
                value: order.grandTotal,
                fontSize: AppFontSizes.size15,
                color: adminFlagForeground(theme, AppColor.adminAccent),
                formatter: orderMoney,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amountRow(BuildContext context, String label, double value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size11,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          Text(
            orderMoney(value),
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.medium,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const CurrencyIcon(size: 11),
        ],
      ),
    );
  }

  Widget _textRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size11,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size11,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
