import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_edit_rules.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderItemRemoveButton extends StatelessWidget {
  const OrderItemRemoveButton({
    super.key,
    required this.order,
    required this.item,
    required this.onRemove,
    this.canRemove = true,
  });

  final AdminOrder order;
  final AdminOrderItem item;
  final ValueChanged<String> onRemove;

  /// False for a role that may read the line but not delete it.
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editable = canRemove && OrderEditRules.canEditItems(order);
    final allowed =
        canRemove &&
        OrderEditRules.canRemoveItem(order, hasItemId: item.id != null);
    final label = !editable
        ? S.orderCannotBeEdited
        : item.id == null
        ? S.removeItemUnavailable
        : S.removeItem;
    return IconButton(
      tooltip: label,
      onPressed: !allowed || item.id == null
          ? null
          : () => showConfirmDeleteSnackBar(
              context,
              message: S.removeItemConfirm,
              onConfirm: () => onRemove(item.id!),
            ),
      style: IconButton.styleFrom(
        fixedSize: const Size(28, 28),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        disabledForegroundColor: adminSubtleColor(theme),
      ),
      icon: AppIcon(
        AppIcons.delete02,
        size: 15,
        color: allowed && item.id != null
            ? AppColor.errorColor
            : adminSubtleColor(theme),
      ),
    );
  }
}
