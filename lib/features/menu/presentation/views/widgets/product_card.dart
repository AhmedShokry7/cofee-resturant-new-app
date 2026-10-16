import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_favorite_button.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_price.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

/// Shared reusable product card used across the entire application.
///
/// All product-list and cart pages must use this component instead of
/// [PopularCard] variants. The card displays the product's primary image from
/// the database, falls back to a neutral unavailable state when no image is
/// available, and uses [CachedNetworkImage] for loading and caching the remote
/// image.
class ProductCard extends StatelessWidget {
  /// Width-to-height ratio of the grid/carousel card. The image area is
  /// [Expanded], so growing the card height flows entirely into a larger
  /// product image while title, description, price and actions keep their
  /// fixed slots.
  static const double cardAspectRatio = 0.64;

  const ProductCard({
    super.key,
    required this.product,
    this.quantity,
    this.onIncrement,
    this.onDecrement,
    this.showFavorite = true,
    this.note = '',
    this.lineId,
    this.unitPrice,
  });

  final ProductModel product;
  final int? quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool showFavorite;
  final String note;
  final String? lineId;
  final double? unitPrice;

  bool get _isCart => quantity != null;

  @override
  Widget build(BuildContext context) {
    if (_isCart) return _buildCartCard(context);

    // Grid cards receive a finite cell width, while carousel children are
    // unbounded horizontally. Give only the latter an explicit width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 150.w;
        return SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: cardAspectRatio,
            child: GestureDetector(
              onTap: () => _openDetails(context),
              child: Container(
                padding: EdgeInsets.all(SpacingTokens.md.w),
                decoration: _decoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: _buildProductImage(),
                            ),
                          ),
                          if (showFavorite)
                            Positioned(
                              top: 2.w,
                              left: 4.w,
                              child: ProductFavoriteButton(
                                product: product,
                                size: 28,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: SpacingTokens.sm.h),
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.semiBold16(context),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      product.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.regular12(context)
                          .copyWith(color: AppColor.greyColor),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Expanded(child: ProductPrice(product: product)),
                        SizedBox(width: SpacingTokens.xs.w),
                        _AddButton(
                          onTap: () => context.read<CartCubit>().add(product),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration get _decoration => BoxDecoration(
    color: AppColor.whiteColor,
    borderRadius: BorderRadius.circular(16.r),
    border: Border.all(color: AppColor.borderColor),
  );

  void _openDetails(BuildContext context) =>
      Navigator.of(context)
          .pushNamed(ProductDetailsPage.routeName, arguments: product);

  Widget _buildProductImage() => ProductImageView(product: product);

  Widget _buildCartCard(BuildContext context) => GestureDetector(
    onTap: () => _openDetails(context),
    child: Container(
      margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: _decoration,
      child: Row(
        children: [
          SizedBox(
            width: 76.w,
            height: 76.w,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: _buildProductImage(),
            ),
          ),
          SizedBox(width: SpacingTokens.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.semiBold16(context),
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
                PriceLabel(
                  amount: (unitPrice ?? product.price) * quantity!,
                  style: AppFonts.semiBold14(context)
                      .copyWith(color: AppColor.primaryColor),
                  iconSize: 14,
                  iconColor: AppColor.primaryColor,
                ),
              ],
            ),
          ),
          SizedBox(width: SpacingTokens.sm.w),
          _QuantityStepper(
            quantity: quantity!,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
          ),
        ],
      ),
    ),
  );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
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
  );
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
        _StepButton(icon: HugeIcons.strokeRoundedRemove01, onTap: onDecrement),
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
