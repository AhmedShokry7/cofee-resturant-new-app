import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/database_error_text.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_detail_controller.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_product_picker.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

/// Changes the status of the order, and reports a failure to the admin.
Future<void> changeOrderStatus(
  BuildContext context,
  OrderDetailController controller,
  String status,
) async {
  try {
    await controller.changeStatus(status);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(
      context,
      databaseErrorText(error, fallback: S.orderActionFailed),
    );
  }
}

/// Changes the payment status of the order, and reports a failure to the admin.
Future<void> changePaymentStatus(
  BuildContext context,
  OrderDetailController controller,
  String paymentStatus,
) async {
  try {
    await controller.changePaymentStatus(paymentStatus);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(
      context,
      databaseErrorText(error, fallback: S.orderActionFailed),
    );
  }
}

/// Asks the admin to pick a product, then adds it as a line of the order.
Future<void> addProductToOrder(
  BuildContext context,
  OrderDetailController controller,
) async {
  final pick = await askProductAndQuantity(
    context: context,
    products: controller.products,
  );
  if (pick == null || !context.mounted) return;
  try {
    await controller.addProduct(pick.product, pick.quantity);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(
      context,
      databaseErrorText(error, fallback: S.orderActionFailed),
    );
  }
}

/// Removes one line of the order, and reports a failure to the admin.
Future<void> removeOrderLine(
  BuildContext context,
  OrderDetailController controller,
  String itemId,
) async {
  try {
    await controller.removeItem(itemId);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(
      context,
      databaseErrorText(error, fallback: S.orderActionFailed),
    );
  }
}
