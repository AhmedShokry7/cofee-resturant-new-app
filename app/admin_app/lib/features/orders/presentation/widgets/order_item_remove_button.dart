import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_edit_rules.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

class OrderItemRemoveButton extends StatelessWidget {
  const OrderItemRemoveButton({
    super.key,
    required this.order,
    required this.item,
    required this.onRemove,
  });
  final AdminOrder order;
  final AdminOrderItem item;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final editable = OrderEditRules.canEditItems(order);
    final allowed = OrderEditRules.canRemoveItem(
      order,
      hasItemId: item.id != null,
    );
    final label = !editable
        ? S.orderCannotBeEdited
        : item.id == null
        ? S.removeItemUnavailable
        : S.removeItem;
    return IconButton(
      tooltip: label,
      color: AppColor.errorColor,
      icon: const HugeIcon(
        icon: HugeIcons.strokeRoundedDelete02,
        size: AppDimensions.xl,
        color: AppColor.errorColor,
      ),
      onPressed: !allowed || item.id == null
          ? null
          : () => showConfirmDeleteSnackBar(
              context,
              message: S.removeItemConfirm,
              onConfirm: () => onRemove(item.id!),
            ),
    );
  }
}
