import 'package:material_ui/material_ui.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_edit_rules.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';

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
    return AdminCreateButton(
      label: S.ordersAddProduct,
      tooltip: enabled ? S.ordersAddProduct : S.orderCannotBeEdited,
      onPressed: enabled ? onPressed : null,
    );
  }
}
