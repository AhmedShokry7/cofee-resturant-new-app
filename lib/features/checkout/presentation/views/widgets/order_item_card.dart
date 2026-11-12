import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_price.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class OrderItemCard extends StatelessWidget {
  const OrderItemCard({
    super.key,
    required this.product,
    this.quantity = 1,
    this.note = '',
    this.unitPrice,
  });

  final ProductModel product;
  final int quantity;
  final String note;

  /// Variant-adjusted unit price. Null = base price (catalog display).
  final double? unitPrice;

  @override
  Widget build(BuildContext context) {
    final effectiveUnit = unitPrice ?? product.price;
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            child: SizedBox(
              height: AppSizes.px64,
              width: AppSizes.px64,
              child: ProductImageView(product: product),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppFonts.semiBold16(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.xxs),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.regular12(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                ],
                SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      '$quantity × ',
                      style: AppFonts.regular12(context)
                          .copyWith(color: AppColor.greyColor),
                    ),
                    Expanded(
                      child: PriceLabel(
                        amount: effectiveUnit,
                        style: AppFonts.regular12(context)
                            .copyWith(color: AppColor.greyColor),
                        iconSize: 12,
                        iconColor: AppColor.greyColor,
                      ),
                    ),
                    if (unitPrice == null)
                      ProductPrice(product: product)
                    else
                      PriceLabel(
                        amount: effectiveUnit * quantity,
                        style: AppFonts.semiBold14(context)
                            .copyWith(color: AppColor.primaryColor),
                        iconSize: 14,
                        iconColor: AppColor.primaryColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
