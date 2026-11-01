import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class ProductPrice extends StatelessWidget {
  const ProductPrice({super.key, required this.product});

  final ProductModel product;

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
          iconSize: 14,
          iconColor: AppColor.primaryColor,
        ),
        // The old price is shown for a discounted product and for a product
        // that only carries a compare-at price. The badge is what says "this
        // is a promotion", so the old price alone does not claim one.
        if (product.hasOldPrice) ...[
          SizedBox(width: AppSizes.px6),
          Flexible(
            child: Text(
              Formatters.amount(product.oldPrice!),
              style: AppFonts.regular12(context).copyWith(
                color: AppColor.greyColor,
                decoration: TextDecoration.lineThrough,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
