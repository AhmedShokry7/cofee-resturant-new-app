import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_favorite_button.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_price.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/animated_add_to_cart_button.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Shared reusable product card used across the entire application.
///
/// All product-list and cart pages must use this component instead of
/// variants. The card displays the product's primary image from
/// the database, falls back to a neutral unavailable state when no image is
/// available, and uses [CachedNetworkImage] for loading and caching the remote
/// image.
class ProductCard extends StatelessWidget {
  /// Width-to-height ratio of the grid/carousel card. The image area is
  /// [Expanded], so growing the card height flows entirely into a larger
  /// product image while title, description, price and actions keep their
  /// fixed slots.
  static const double cardAspectRatio = AppDimensions.productCardAspect;

  /// Width of a card inside a horizontal strip (home carousel), in logical
  /// pixels. Wide enough for the price and the struck-through old price to
  /// sit side by side without either of them being cut.
  static const double stripWidth = AppDimensions.productCardWidth;

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
    this.onTap,
  });

  final ProductModel product;
  final int? quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool showFavorite;
  final String note;
  final String? lineId;
  final double? unitPrice;
  final VoidCallback? onTap;

  bool get _isCart => quantity != null;

  /// The price of one piece before the discount, when one applies.
  ///
  /// A variant carries the option deltas on top of the product price, so the
  /// price before the discount of the variant is the price before the
  /// discount of the product plus the same deltas.
  double? get _oldUnitPrice {
    final oldPrice = product.oldPrice;
    if (oldPrice == null) return null;
    final effective = unitPrice ?? product.price;
    final old = oldPrice + (effective - product.price);
    return old > effective ? old : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCart) return _buildCartCard(context);

    // Grid cards receive a finite cell width, while carousel children are
    // unbounded horizontally. Give only the latter an explicit width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : stripWidth;
        return SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: cardAspectRatio,
            child: GestureDetector(
              onTap: () => _openDetails(context),
              child: Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: _decoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.cardRadius,
                              ),
                              child: _buildProductImage(),
                            ),
                          ),
                          if (showFavorite)
                            Positioned(
                              top: AppSpacing.xxs,
                              left: AppSpacing.xs,
                              child: ProductFavoriteButton(
                                product: product,
                                size: AppDimensions.favoriteButtonCard,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.semiBold16(context),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      product.category.trim().isEmpty
                          ? product.description
                          : product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.regular12(context)
                          .copyWith(color: AppColor.greyColor),
                    ),
                    SizedBox(height: AppSizes.px6),
                    Row(
                      children: [
                        Expanded(child: ProductPrice(product: product)),
                        SizedBox(width: AppSpacing.xs),
                        AnimatedAddToCartIconButton(
                          size: AppDimensions.addToCartButtonCard,
                          onAdd: () async =>
                              context.read<CartCubit>().add(product),
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
    borderRadius: BorderRadius.circular(AppRadius.r16),
    border: Border.all(color: AppColor.borderColor),
  );

  void _openDetails(BuildContext context) {
    final handler = onTap;
    if (handler != null) {
      handler();
      return;
    }
    Navigator.of(context)
        .pushNamed(ProductDetailsPage.routeName, arguments: product);
  }

  Widget _buildProductImage() => ProductImageView(product: product);

  Widget _buildCartCard(BuildContext context) => GestureDetector(
    onTap: () => _openDetails(context),
    child: Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: _decoration,
      child: Row(
        children: [
          SizedBox(
            width: AppSizes.px76,
            height: AppSizes.px76,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              child: _buildProductImage(),
            ),
          ),
          SizedBox(width: AppSpacing.md),
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
                    PriceLabel(
                      amount: (unitPrice ?? product.price) * quantity!,
                      style: AppFonts.semiBold14(context)
                          .copyWith(color: AppColor.primaryColor),
                      iconColor: AppColor.primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          // The price of one piece sits right above the add button, so the
          // customer can see what a single piece costs while they raise the
          // quantity. The line total stays where it is, under the name.
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PriceLabel(
                    amount: unitPrice ?? product.price,
                    style: AppFonts.regular12(context)
                        .copyWith(color: AppColor.greyColor),
                    iconColor: AppColor.greyColor,
                  ),
                  // The price before the discount, so the line explains
                  // itself.
                  if (_oldUnitPrice != null) ...[
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      Formatters.amount(_oldUnitPrice!),
                      style: AppFonts.regular12(context).copyWith(
                        color: AppColor.greyColor,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: AppSizes.px6),
              _QuantityStepper(
                quantity: quantity!,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              ),
            ],
          ),
        ],
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
        _StepButton(icon: AppIcons.remove, onTap: onDecrement),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('$quantity', style: AppFonts.semiBold16(context)),
        ),
        _StepButton(icon: AppIcons.add, onTap: onIncrement),
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
        height: AppSizes.px30,
        width: AppSizes.px30,
        decoration: const BoxDecoration(
          color: AppColor.lightGreyColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: AppSpacing.lg, color: AppColor.primaryColor),
      ),
    );
  }
}
