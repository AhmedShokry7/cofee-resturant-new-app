import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_price.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

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
      margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: SizedBox(
              height: 64.w,
              width: 64.w,
              child: ProductImageView(product: product),
            ),
          ),
          SizedBox(width: SpacingTokens.md.w),
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
                  SizedBox(height: 2.h),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.regular12(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                ],
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      "$quantity × ${Formatters.price(effectiveUnit)}",
                      style: AppFonts.regular12(context)
                          .copyWith(color: AppColor.greyColor),
                    ),
                    const Spacer(),
                    if (unitPrice == null)
                      ProductPrice(product: product)
                    else
                      Text(
                        Formatters.price(effectiveUnit * quantity),
                        style: AppFonts.semiBold14(context)
                            .copyWith(color: AppColor.primaryColor),
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
