import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_favorite_button.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_price.dart';
import 'package:new_coffee/shared/widgets/animated_add_to_cart_button.dart';

class PopularCard extends StatelessWidget {
  const PopularCard({super.key, required this.product, this.width});

  final ProductModel product;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.of(context)
              .pushNamed(ProductDetailsPage.routeName, arguments: product),
      child: Container(
        width: width?.w,
        padding: EdgeInsets.all(SpacingTokens.md.w),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: ProductImageView(product: product),
                    ),
                  ),
                  Positioned(
                    top: 6.w,
                    right: 6.w,
                    child: ProductFavoriteButton(product: product),
                  ),
                ],
              ),
            ),
            SizedBox(height: SpacingTokens.sm.h),
            Text(
              product.name,
              style: AppFonts.semiBold14(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: ProductPrice(product: product)),
                SizedBox(width: SpacingTokens.xs.w),
                AnimatedAddToCartIconButton(
                  size: 28,
                  onAdd: () async => context.read<CartCubit>().add(product),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
