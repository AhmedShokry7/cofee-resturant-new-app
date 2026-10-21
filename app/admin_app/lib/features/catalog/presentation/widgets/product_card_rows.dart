import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_fields.dart';

/// Language code, the product name and the trailing action.
class ProductCardNameRow extends StatelessWidget {
  const ProductCardNameRow({super.key, required this.product, this.onMore});

  final AdminProduct product;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RecordLanguageTag(label: S.languageCode),
        Expanded(
          child: RecordValueBox(
            value: product.name,
            alignEnd: true,
            trailing: RecordActionBox(
              icon: HugeIcons.strokeRoundedArrowDown01,
              onTap: onMore,
            ),
          ),
        ),
      ],
    );
  }
}

/// Currency, the price and the trailing action.
class ProductCardPriceRow extends StatelessWidget {
  const ProductCardPriceRow({super.key, required this.product, this.onMore});

  final AdminProduct product;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: AppDimensions.recordPriceRowWidth,
        child: Row(
          children: [
            RecordActionBox(
              icon: HugeIcons.strokeRoundedEdit02,
              onTap: onMore,
              radiusEnd: true,
            ),
            RecordCurrencyBox(label: S.currency),
            Expanded(
              child: RecordValueBox(
                value: formatMoney(product.basePrice),
                alignEnd: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Options and quantity row with its check box and counters.
class ProductCardOptionsRow extends StatelessWidget {
  const ProductCardOptionsRow({
    super.key,
    required this.product,
    this.onToggleFeatured,
    this.onMore,
  });

  final AdminProduct product;
  final VoidCallback? onToggleFeatured;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RecordLabelBox(label: S.optionsAndQuantity),
        const SizedBox(width: 1),
        RecordActionBox(
          icon: HugeIcons.strokeRoundedTick01,
          onTap: onToggleFeatured,
          active: product.isFeatured,
          width: AppDimensions.recordCheckBoxColumnWidth,
        ),
        const SizedBox(width: 1),
        RecordActionBox(
          icon: HugeIcons.strokeRoundedDelete01,
          onTap: onMore,
          width: AppDimensions.recordFieldActionWidth,
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: RecordValueBox(
                  value: '${product.prepMinutes ?? 0}',
                  alignEnd: true,
                ),
              ),
              RecordActionBox(
                icon: HugeIcons.strokeRoundedAdd01,
                onTap: onMore,
                width: AppDimensions.recordCheckBoxColumnWidth,
                radiusEnd: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A label box followed by a read only value that looks like a select.
class ProductCardSelectRow extends StatelessWidget {
  const ProductCardSelectRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.muted = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RecordLabelBox(label: label),
        Expanded(
          child: RecordValueBox(
            value: value,
            alignEnd: true,
            muted: muted,
            trailing: RecordActionBox(
              icon: HugeIcons.strokeRoundedArrowDown01,
              onTap: onTap,
              radiusEnd: true,
            ),
          ),
        ),
      ],
    );
  }
}
