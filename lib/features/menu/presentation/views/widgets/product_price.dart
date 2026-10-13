import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

class ProductPrice extends StatelessWidget {
  const ProductPrice({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Formatters.price(product.price),
          style: AppFonts.semiBold14(
            context,
          ).copyWith(color: AppColor.primaryColor),
        ),
        if (product.hasDiscount) ...[
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              Formatters.price(product.oldPrice!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.regular12(context).copyWith(
                color: AppColor.greyColor,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
