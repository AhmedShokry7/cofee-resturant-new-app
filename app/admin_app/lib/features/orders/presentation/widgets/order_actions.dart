import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_detail_controller.dart';
import 'package:admin_app/features/orders/presentation/order_refusal_reasons.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_product_picker.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

/// Changes the status of the order, and reports a failure to the admin.
///
/// الـ Cubit يرد false حين ترفض القاعدة الكتابة أو كان حفظًا آخر جارياً، فلا
/// يكفي catch وحده: الصمت هنا يعني أن الأدمن ظنّ الحالة تغيّرت.
Future<void> changeOrderStatus(
  BuildContext context,
  OrderDetailController controller,
  String status,
) async {
  try {
    final applied = await controller.changeStatus(status);
    if (applied || !context.mounted) return;
    showErrorSnackBar(context, S.orderActionFailed);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(
      context,
      adminErrorMessage(
        error,
        fallback: S.orderActionFailed,
        reasons: orderRefusalReasons(),
      ),
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
    final applied = await controller.changePaymentStatus(paymentStatus);
    if (applied || !context.mounted) return;
    showErrorSnackBar(context, S.orderActionFailed);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(
      context,
      adminErrorMessage(
        error,
        fallback: S.orderActionFailed,
        reasons: orderRefusalReasons(),
      ),
    );
  }
}

/// Asks the admin to pick a product, then adds it as a line of the order.
///
/// قائمة منتجات فشل قراءتها تُعاد مرة واحدة قبل فتح المنتقي، فإن بقيت فارغة
/// مع الفشل تُقال بصيغة الفشل: «لا توجد منتجات» توهم الأدمن أن الفرع فارغ.
Future<void> addProductToOrder(
  BuildContext context,
  OrderDetailController controller,
) async {
  if (controller.productsFailed) {
    await controller.loadProducts();
    if (!context.mounted) return;
  }
  if (controller.products.isEmpty && controller.productsFailed) {
    showErrorSnackBar(context, S.ordersCatalogLoadFailed);
    return;
  }
  final pick = await askProductAndQuantity(
    context: context,
    products: controller.products,
  );
  if (pick == null || !context.mounted) return;
  try {
    final applied = await controller.addProduct(pick.product, pick.quantity);
    if (applied || !context.mounted) return;
    showErrorSnackBar(context, S.orderActionFailed);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(
      context,
      adminErrorMessage(
        error,
        fallback: S.orderActionFailed,
        reasons: orderRefusalReasons(),
      ),
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
    final applied = await controller.removeItem(itemId);
    if (applied || !context.mounted) return;
    showErrorSnackBar(context, S.orderActionFailed);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(
      context,
      adminErrorMessage(
        error,
        fallback: S.orderActionFailed,
        reasons: orderRefusalReasons(),
      ),
    );
  }
}
