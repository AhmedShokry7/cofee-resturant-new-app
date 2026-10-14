import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_favorite_button.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_price.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.quantity,
    this.onIncrement,
    this.onDecrement,
    this.showFavorite = true,
    this.note = '',
    this.unitPrice,
  });

  final ProductModel product;
  final int? quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool showFavorite;
  final String note;

  /// Variant-adjusted unit price for cart lines. Null = base price.
  final double? unitPrice;

  bool get _isCart => quantity != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).pushNamed(ProductDetailsPage.routeName, arguments: product),
      child: Container(
        margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
        padding: EdgeInsets.all(SpacingTokens.md.w),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: Row(
          children: [
            Stack(
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
                if (showFavorite)
                  Positioned(
                    top: 2.w,
                    left: 4.w,
                    child: ProductFavoriteButton(product: product, size: 28),
                  ),
              ],
            ),
            SizedBox(width: SpacingTokens.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: AppFonts.semiBold16(context)),
                  if (note.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.regular12(
                        context,
                      ).copyWith(color: AppColor.greyColor),
                    ),
                  ],
                  SizedBox(height: 4.h),
                  if (_isCart)
                    Text(
                      Formatters.price(
                        (unitPrice ?? product.price) * quantity!,
                      ),
                      style: AppFonts.semiBold14(
                        context,
                      ).copyWith(color: AppColor.primaryColor),
                    )
                  else
                    Text(
                      product.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.regular12(
                        context,
                      ).copyWith(color: AppColor.greyColor),
                    ),
                  if (!_isCart) ...[
                    SizedBox(height: 6.h),
                    ProductPrice(product: product),
                  ],
                ],
              ),
            ),
            SizedBox(width: SpacingTokens.sm.w),
            if (_isCart)
              _QuantityStepper(
                quantity: quantity!,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              )
            else
              GestureDetector(
                onTap: () => context.read<CartCubit>().add(product),
                child: Container(
                  height: 36.w,
                  width: 36.w,
                  decoration: const BoxDecoration(
                    color: AppColor.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    HugeIcons.strokeRoundedAdd01,
                    size: 20.w,
                    color: AppColor.whiteColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    this.onIncrement,
    this.onDecrement,
  });

  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: HugeIcons.strokeRoundedRemove01,
          onTap: onDecrement,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: SpacingTokens.sm.w),
          child: Text('$quantity', style: AppFonts.semiBold16(context)),
        ),
        _StepButton(icon: HugeIcons.strokeRoundedAdd01, onTap: onIncrement),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30.w,
        width: 30.w,
        decoration: const BoxDecoration(
          color: AppColor.lightGreyColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16.w, color: AppColor.primaryColor),
      ),
    );
  }
}

