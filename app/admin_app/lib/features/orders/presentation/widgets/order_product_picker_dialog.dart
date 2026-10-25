import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_product_picker_tile.dart';

class ProductPickerDialog extends StatefulWidget {
  const ProductPickerDialog({super.key, required this.products});
  final List<AdminProduct> products;
  @override
  State<ProductPickerDialog> createState() => _OrderProductPickerDialogState();
}

class _OrderProductPickerDialogState extends State<ProductPickerDialog> {
  List<AdminProduct> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.products;
  }

  void _search(String value) {
    final query = value.trim().toLowerCase();
    setState(
      () => _filtered = query.isEmpty
          ? widget.products
          : widget.products
                .where(
                  (product) =>
                      product.nameAr.toLowerCase().contains(query) ||
                      product.nameEn.toLowerCase().contains(query),
                )
                .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(S.ordersAddProduct),
      content: SizedBox(
        width: (size.width * .9).clamp(280.0, 440.0).toDouble(),
        height: (size.height * .6).clamp(240.0, 440.0).toDouble(),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(labelText: S.ordersSearch),
              onChanged: _search,
            ),
            const SizedBox(height: AppDimensions.md),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(child: Text(S.ordersNoProductsFound))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) => OrderProductPickerTile(
                        product: _filtered[index],
                        onTap: () =>
                            Navigator.of(context).pop(_filtered[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.ordersCancel),
        ),
      ],
    );
  }
}
