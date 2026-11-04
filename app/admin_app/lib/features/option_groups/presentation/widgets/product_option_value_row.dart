import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_price_field.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_reset_button.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_value_caption.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';

/// سطر خيار واحد في حوار المشروب: اسمه، وحقل زيادته عنده، والسعر النهائي.
///
/// السعر النهائي معاينة حيّة من الحقل، لا رقم محفوظ: الذي يبيعه للعميل تحلّه
/// `catalog.option_value_delta` ثم `resolve_effective_price` في القاعدة، والحوار
/// يعيد قراءتهما بعد كل حفظ فيعرض جوابهما لا حساب الشاشة.
class ProductOptionValueRow extends StatefulWidget {
  const ProductOptionValueRow({
    super.key,
    required this.value,
    required this.basePrice,
    required this.controller,
    required this.onReset,
  });

  final AdminProductOptionValue value;
  final double basePrice;
  final TextEditingController controller;
  final VoidCallback onReset;

  @override
  State<ProductOptionValueRow> createState() => _ProductOptionValueRowState();
}

class _ProductOptionValueRowState extends State<ProductOptionValueRow> {
  @override
  void initState() {
    super.initState();
    // السطر keyed بمعرّف الخيار وحقلُه لا يتبدّل، فمستمع واحد يكفي.
    widget.controller.addListener(_onTyped);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTyped);
    super.dispose();
  }

  void _onTyped() => setState(() {});

  /// الحقل الفارغ ليس صفرًا: هو رجوع إلى زيادة المجموعة.
  double get _delta {
    final typed = double.tryParse(
      normalizeDigits(widget.controller.text.trim()),
    );
    return typed ?? widget.value.groupDelta;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: ProductOptionValueCaption(value: widget.value),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 4,
            child: ProductOptionPriceField(
              valueId: widget.value.id,
              controller: widget.controller,
              groupDelta: widget.value.groupDelta,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: AppDimensions.productOptionPriceWidth,
            child: AdminMoneyText(
              key: ValueKey('product-option-final-${widget.value.id}'),
              value: widget.basePrice + _delta,
              fontSize: AppFontSizes.size11,
            ),
          ),
          // الزرّ يعني «امحُ ما كتبته»، وهو محوُ إلا بكتابة أو بتجاوز محفوظ.
          if (widget.value.hasOwnPrice || widget.controller.text.isNotEmpty)
            ProductOptionResetButton(
              valueId: widget.value.id,
              onPressed: widget.onReset,
            ),
        ],
      ),
    );
  }
}
