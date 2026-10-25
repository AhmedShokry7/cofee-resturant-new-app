import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
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
  Widget build(BuildContext context) => Column(
    children: [
      if (paymentMethodLabel?.trim().isNotEmpty == true)
        _textRow(context, S.paymentMethod, paymentMethodLabel!),
      _amountRow(context, S.subtotal, order.subtotal),
      if (order.discountTotal > 0)
        _amountRow(context, S.discount, -order.discountTotal),
      if (order.fulfillmentType == 'delivery')
        _amountRow(context, S.deliveryFee, order.deliveryFee),
      if (order.taxTotal > 0) _amountRow(context, S.tax, order.taxTotal),
      const Divider(height: AppDimensions.lg),
      Row(
        children: [
          Expanded(
            child: Text(
              S.grandTotal,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            formatAmount(order.grandTotal),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColor.primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppDimensions.xs),
          const CurrencyIcon(size: 16, color: AppColor.primaryColor),
        ],
      ),
    ],
  );

  Widget _amountRow(BuildContext context, String label, double value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(formatAmount(value)),
            const SizedBox(width: AppDimensions.xs),
            const CurrencyIcon(size: 12),
          ],
        ),
      );

  Widget _textRow(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(value),
      ],
    ),
  );
}
