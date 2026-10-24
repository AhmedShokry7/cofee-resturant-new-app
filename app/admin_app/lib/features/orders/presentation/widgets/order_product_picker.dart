import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';

/// Asks the admin to pick a product from the catalogue of the dashboard, and
/// then the quantity of it.
Future<({AdminProduct product, int quantity})?> askProductAndQuantity({
  required BuildContext context,
  required List<AdminProduct> products,
}) async {
  final product = await showDialog<AdminProduct>(
    context: context,
    builder: (context) => ProductPickerDialog(products: products),
  );
  if (product == null || !context.mounted) return null;

  final quantity = await showDialog<int>(
    context: context,
    builder: (context) => QuantityDialog(initial: 1),
  );
  if (quantity == null) return null;
  return (product: product, quantity: quantity);
}

/// The list of the products of the dashboard, with a search box on top.
class ProductPickerDialog extends StatefulWidget {
  const ProductPickerDialog({super.key, required this.products});

  final List<AdminProduct> products;

  @override
  State<ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<ProductPickerDialog> {
  late List<AdminProduct> _filtered = widget.products;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.addProduct),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(labelText: S.search),
              onChanged: (value) {
                final term = value.trim().toLowerCase();
                setState(() {
                  _filtered = term.isEmpty
                      ? List.from(widget.products)
                      : widget.products
                            .where(
                              (p) =>
                                  p.nameAr.toLowerCase().contains(term) ||
                                  p.nameEn.toLowerCase().contains(term),
                            )
                            .toList();
                });
              },
            ),
            const SizedBox(height: AppDimensions.md),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(child: Text(S.noProductsFound))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final p = _filtered[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child:
                                  p.imageUrl != null &&
                                      p.imageUrl!.trim().isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: p.imageUrl!,
                                      fit: BoxFit.fill,
                                      errorWidget: (_, _, _) =>
                                          const ColoredBox(
                                            color: AppColor.secondaryColor,
                                            child: Icon(
                                              HugeIcons
                                                  .strokeRoundedShoppingBag01,
                                            ),
                                          ),
                                    )
                                  : const ColoredBox(
                                      color: AppColor.secondaryColor,
                                      child: Icon(
                                        HugeIcons.strokeRoundedShoppingBag01,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(p.nameFor(AppLocale.instance.language)),
                          subtitle: Text(
                            '${p.basePrice.toStringAsFixed(2)} SAR',
                          ),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
      ],
    );
  }
}

/// Asks how many units of the product the admin wants to add.
class QuantityDialog extends StatefulWidget {
  const QuantityDialog({super.key, this.initial = 1});

  final int initial;

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initial}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _accept() {
    final q = int.tryParse(_controller.text.trim());
    Navigator.of(context).pop(q != null && q > 0 ? q : widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.quantity),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        onSubmitted: (_) => _accept(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(onPressed: _accept, child: Text(S.add)),
      ],
    );
  }
}
