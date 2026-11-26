import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_price_field.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_reset_button.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_value_caption.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// Option price editor with a compact layout for narrow product dialogs.
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
    widget.controller.addListener(_onTyped);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTyped);
    super.dispose();
  }

  void _onTyped() => setState(() {});

  double get _delta {
    final typed = double.tryParse(
      normalizeDigits(widget.controller.text.trim()),
    );
    return typed ?? widget.value.groupDelta;
  }

  bool get _hasOverride =>
      widget.value.hasOwnPrice || widget.controller.text.isNotEmpty;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final priceField = ProductOptionPriceField(
          valueId: widget.value.id,
          controller: widget.controller,
          groupDelta: widget.value.groupDelta,
        );
        final finalPrice = _finalPrice(context);
        final reset = _hasOverride
            ? ProductOptionResetButton(
                valueId: widget.value.id,
                onPressed: widget.onReset,
              )
            : null;

        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductOptionValueCaption(value: widget.value),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: priceField),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: finalPrice),
                  if (reset != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    reset,
                  ],
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              flex: 5,
              child: ProductOptionValueCaption(value: widget.value),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 4, child: priceField),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: AppDimensions.productOptionPriceWidth,
              child: finalPrice,
            ),
            ?reset,
          ],
        );
      },
    ),
  );

  Widget _finalPrice(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        S.finalPriceLabel,
        style: TextStyle(
          color: adminMutedColor(Theme.of(context)),
          fontSize: AppFontSizes.size9,
        ),
      ),
      AdminMoneyText(
        key: ValueKey('product-option-final-${widget.value.id}'),
        value: widget.basePrice + _delta,
        fontSize: AppFontSizes.size11,
      ),
    ],
  );
}
