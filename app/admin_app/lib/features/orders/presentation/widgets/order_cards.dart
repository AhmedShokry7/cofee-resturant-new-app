import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_card_customer.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_card_heading.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_card_metadata.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onChangeStatus,
    this.onTap,
  });
  final AdminOrder order;
  final ValueChanged<String>? onChangeStatus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.recordCardRadius);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderCardHeading(order: order, onChangeStatus: onChangeStatus),
              const SizedBox(height: AppDimensions.sm),
              OrderCardCustomer(order: order),
              const SizedBox(height: AppDimensions.sm),
              OrderCardMetadata(order: order),
            ],
          ),
        ),
      ),
    );
  }
}
