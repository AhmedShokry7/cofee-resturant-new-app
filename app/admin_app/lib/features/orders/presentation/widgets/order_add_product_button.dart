import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/presentation/models/order_edit_rules.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';

class OrderAddProductButton extends StatelessWidget {
  const OrderAddProductButton({
    super.key,
    required this.order,
    required this.onPressed,
  });
  final AdminOrder order;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = OrderEditRules.canEditItems(order);
    return Tooltip(
      message: enabled ? S.ordersAddProduct : S.orderCannotBeEdited,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FilledButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedAdd01,
            size: AppDimensions.xl,
            color: AppColor.whiteColor,
          ),
          label: Text(S.ordersAddProduct),
        ),
      ),
    );
  }
}
