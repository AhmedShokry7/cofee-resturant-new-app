import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class ProductDetailsBottomBar extends StatelessWidget {
  const ProductDetailsBottomBar({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SpacingTokens.lg.w),
      decoration: const BoxDecoration(
        color: AppColor.whiteColor,
        border: Border(top: BorderSide(color: AppColor.borderColor)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Total Price",
                style: AppFonts.regular14(
                  context,
                ).copyWith(color: AppColor.greyColor),
              ),
              SizedBox(height: 4.h),
              Text(
                Formatters.price(product.price),
                style: AppFonts.semiBold18(context),
              ),
            ],
          ),
          SizedBox(width: SpacingTokens.lg.w),
          Expanded(
            child: CustomBtn(
              text: "Add to Cart",
              onPressed: () {
                context.read<CartCubit>().add(product);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Added to cart")),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
