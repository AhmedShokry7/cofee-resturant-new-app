import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/locale/app_strings.dart';

import 'package:admin_app/features/catalog/presentation/widgets/product_card_fields.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// The title row: the product mark and the name of the product.
class ProductCardNameRow extends StatelessWidget {
  const ProductCardNameRow({
    super.key,
    required this.nameController,
    this.onMore,
    this.moreKey,
  });

  final TextEditingController nameController;
  final VoidCallback? onMore;

  /// Finds the button of the menu, so the menu opens under it.
  final GlobalKey? moreKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RecordActionBox(
          key: moreKey,
          icon: HugeIcons.strokeRoundedPackage,
          onTap: onMore,
          radiusStart: true,
        ),
        Expanded(
          child: RecordTextFieldBox(
            controller: nameController,
            hint: S.productName,
          ),
        ),
      ],
    );
  }
}

/// The price row: the currency mark, the price and the Riyal symbol.
///
/// When the product carries a discount, the price the customer pays is stated
/// under the field, so the admin sees what the catalogue will sell for.
class ProductCardPriceRow extends StatelessWidget {
  const ProductCardPriceRow({
    super.key,
    required this.priceController,
    this.discountedPrice,
    this.discountPercentage,
    this.discountActive = true,
    this.onMore,
  });

  final TextEditingController priceController;

  /// The price after the discount, when one applies.
  final double? discountedPrice;

  /// The discount in percent.
  final double? discountPercentage;

  /// False when the discount is scheduled or expired.
  final bool discountActive;

  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        RecordActionBox(
          icon: HugeIcons.strokeRoundedMoney01,
          onTap: onMore,
          radiusStart: true,
        ),
        Expanded(
          child: RecordTextFieldBox(
            controller: priceController,
            hint: S.price,
            textInputType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
        ),
        RecordActionBox(
          onTap: onMore,
          radiusEnd: true,
          child: const CurrencyIcon(size: 14),
        ),
      ],
    );

    return row;
  }
}

/// The category row: the category of the product and the add action.
class ProductCardCategoryRow extends StatelessWidget {
  const ProductCardCategoryRow({
    super.key,
    required this.categoryName,
    required this.onPickCategory,
    this.onAddCategory,
    this.muted = false,
  });

  final String categoryName;
  final VoidCallback? onPickCategory;
  final VoidCallback? onAddCategory;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RecordSelectBox(
            value: categoryName,
            onTap: onPickCategory,
            muted: muted,
          ),
        ),
        RecordActionLabelBox(
          icon: HugeIcons.strokeRoundedAdd01,
          label: S.addCategoryShort,
          onTap: onAddCategory,
          radiusEnd: true,
        ),
      ],
    );
  }
}
