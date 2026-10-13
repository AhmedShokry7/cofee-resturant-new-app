import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_price.dart';

class OrderItemCard extends StatelessWidget {
  const OrderItemCard({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
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
            child: Image.asset(
              product.image,
              height: 64.w,
              width: 64.w,
              fit: BoxFit.cover,
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
                SizedBox(height: 4.h),
                Text(
                  product.category,
                  style: AppFonts.regular12(
                    context,
                  ).copyWith(color: AppColor.greyColor),
                ),
                SizedBox(height: 6.h),
                ProductPrice(product: product),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
