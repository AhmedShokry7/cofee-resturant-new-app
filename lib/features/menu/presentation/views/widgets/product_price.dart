import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class ProductPrice extends StatelessWidget {
  const ProductPrice({
    super.key,
    required this.product,
    this.showOldPrice = true,
  });

  final ProductModel product;

  /// Whether the struck-through old price sits beside the live price. Cards
  /// that place it on its own line pass false.
  final bool showOldPrice;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The live price keeps its natural width: it is the number the
        // customer reads, so it must never be squeezed out. Only the
        // struck-through old price is allowed to shrink.
        PriceLabel(
          amount: product.price,
          style: AppFonts.semiBold14(context)
              .copyWith(color: AppColor.primaryColor),
          iconSize: AppSizes.px14,
          iconColor: AppColor.primaryColor,
        ),
        // The struck number is the price before the discount (or the admin's
        // compare-at price). Nothing else marks a promotion — the percentage
        // badge is gone, so this row is the whole story.
        if (showOldPrice && product.hasOldPrice) ...[
          SizedBox(width: AppSizes.px6),
          Flexible(child: ProductOldPrice(product: product)),
        ],
      ],
    );
  }
}

/// The struck-through price before the discount, on one line.
///
/// Always occupies one line: a product without a discount gets a blank line
/// of the same height, so every card in a row lines up.
class ProductOldPrice extends StatelessWidget {
  const ProductOldPrice({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Text(
      product.hasOldPrice ? Formatters.amount(product.oldPrice!) : '\u00A0',
      style: AppFonts.regular12(context).copyWith(
        color: AppColor.greyColor,
        // The strike belongs to a real price only; on the blank placeholder
        // it would draw a stray dash.
        decoration: product.hasOldPrice
            ? TextDecoration.lineThrough
            : TextDecoration.none,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
