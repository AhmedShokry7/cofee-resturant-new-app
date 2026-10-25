import 'package:flutter/material.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_product_picker_dialog.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_quantity_dialog.dart';

export 'order_product_picker_dialog.dart';
export 'order_quantity_dialog.dart';

Future<({AdminProduct product, int quantity})?> askProductAndQuantity({
  required BuildContext context,
  required List<AdminProduct> products,
}) async {
  final product = await showDialog<AdminProduct>(
    context: context,
    builder: (_) => ProductPickerDialog(products: products),
  );
  if (product == null || !context.mounted) return null;
  final quantity = await showDialog<int>(
    context: context,
    builder: (_) => const QuantityDialog(),
  );
  return quantity == null ? null : (product: product, quantity: quantity);
}
