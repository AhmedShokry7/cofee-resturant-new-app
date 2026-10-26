import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_financial_summary.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_payment_status_control.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminSectionCard(
      title: S.paymentInfoTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderPaymentStatusControl(
            order: order,
            saving: saving,
            onChanged: onPaymentStatusChanged,
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: adminRowBorderColor(theme)),
          const SizedBox(height: 12),
          OrderFinancialSummary(
            order: order,
            paymentMethodLabel: paymentMethodLabel,
          ),
        ],
      ),
    );
  }
}
