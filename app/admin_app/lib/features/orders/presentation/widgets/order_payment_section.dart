import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_section_card.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// What the order costs and how it is paid.
///
/// The totals are the authoritative values of the order; nothing is
/// recalculated here. The payment method is only shown when the backend
/// returns it â€” the current `admin_orders` RPC does not, so the row stays
/// hidden rather than guessing.
class OrderPaymentSection extends StatelessWidget {
  const OrderPaymentSection({
    super.key,
    required this.order,
    this.paymentMethodLabel,
    this.saving = false,
    this.onPaymentStatusChanged,
  });

  final AdminOrder order;

  /// The localized name of the payment method, when the backend sent one.
  final String? paymentMethodLabel;

  /// True while a payment-status write is in flight.
  final bool saving;

  /// Called when the admin picks a new payment status.
  final ValueChanged<String>? onPaymentStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payment = OrderPaymentStatusView.of(order.paymentStatus);
    return OrderSectionCard(
      title: S.paymentInfoTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           Row(
             children: [
               Expanded(
                 child: Text(
                   S.paymentStatusLabelTitle,
                   style: theme.textTheme.bodySmall?.copyWith(
                     color: AppColor.greyColor,
                   ),
                 ),
               ),
               const SizedBox(width: AppDimensions.sm),
               AdminStatusBadge(label: payment.label, color: payment.color),
             ],
           ),
           if (onPaymentStatusChanged != null) ...[
             const SizedBox(height: AppDimensions.sm),
             DropdownButtonFormField<String>(
               isExpanded: true,
               initialValue: order.paymentStatus,
               decoration: InputDecoration(labelText: S.changePaymentStatus),
               items: [
                 for (final code in OrderPaymentStatusView.allCodes)
                   DropdownMenuItem(
                     value: code,
                     child: Text(
                       OrderPaymentStatusView.of(code).label,
                       style: TextStyle(
                         color: OrderPaymentStatusView.of(code).color,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ),
               ],
               onChanged: saving
                   ? null
                   : (value) {
                       if (value != null) onPaymentStatusChanged!(value);
                     },
             ),
             if (saving)
               Padding(
                 padding: const EdgeInsets.only(top: AppDimensions.xs),
                 child: Row(
                   children: const [
                     SizedBox(
                       width: AppDimensions.spinnerSize,
                       height: AppDimensions.spinnerSize,
                       child: CircularProgressIndicator(
                         strokeWidth: AppDimensions.spinnerStroke,
                       ),
                     ),
                   ],
                 ),
               ),
           ],
          if (paymentMethodLabel != null &&
              paymentMethodLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: AppDimensions.xs),
            _textRow(theme, S.paymentMethod, paymentMethodLabel!),
          ],
          const SizedBox(height: AppDimensions.xs),
          _amountRow(theme, S.subtotal, order.subtotal),
          if (order.discountTotal > 0)
            _amountRow(theme, S.discount, -order.discountTotal),
          if (order.fulfillmentType == 'delivery')
            _amountRow(theme, S.deliveryFee, order.deliveryFee),
          if (order.taxTotal > 0) _amountRow(theme, S.tax, order.taxTotal),
          const Divider(height: AppDimensions.lg),
          _totalRow(theme),
        ],
      ),
    );
  }

  Widget _amountRow(ThemeData theme, String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(
            value.toStringAsFixed(2),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppDimensions.xs),
          const CurrencyIcon(size: 12),
        ],
      ),
    );
  }

  Widget _textRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            S.grandTotal,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          order.grandTotal.toStringAsFixed(2),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColor.primaryColor,
          ),
        ),
        const SizedBox(width: AppDimensions.xs),
        CurrencyIcon(size: 16, color: AppColor.primaryColor),
      ],
    );
  }
}
