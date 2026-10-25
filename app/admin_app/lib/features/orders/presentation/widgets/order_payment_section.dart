import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_financial_summary.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_payment_status_control.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_section_card.dart';

class OrderPaymentSection extends StatelessWidget {
  const OrderPaymentSection({
    super.key,
    required this.order,
    this.paymentMethodLabel,
    this.saving = false,
    this.onPaymentStatusChanged,
  });
  final AdminOrder order;
  final String? paymentMethodLabel;
  final bool saving;
  final ValueChanged<String>? onPaymentStatusChanged;

  @override
  Widget build(BuildContext context) => OrderSectionCard(
    title: S.paymentInfoTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrderPaymentStatusControl(
          order: order,
          saving: saving,
          onChanged: onPaymentStatusChanged,
        ),
        const SizedBox(height: AppDimensions.md),
        OrderFinancialSummary(
          order: order,
          paymentMethodLabel: paymentMethodLabel,
        ),
      ],
    ),
  );
}
