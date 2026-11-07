import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/utils/direction_aware_icons.dart';
import 'package:new_coffee/shared/widgets/animated_add_to_cart_button.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

/// The products an answer is about, as cards under it.
///
/// They are the rows the assistant named, not a carousel of what it thinks the
/// customer might buy: a reply about a price points at the line it read the
/// price from.
class AssistantProductList extends StatelessWidget {
  const AssistantProductList({super.key, required this.products});

  final List<ProductModel> products;

  /// The chat stays where it is: the product page opens on top of it, so the
  /// customer comes back to the same conversation with the same questions.
  void _open(BuildContext context, ProductModel product) {
    context.read<AssistantCubit>().recordProductInterest(product);
    rootNavigatorKey.currentState?.pushNamed(
      ProductDetailsPage.routeName,
      arguments: product,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final product in products)
          GestureDetector(
            onTap: () => _open(context, product),
            child: Container(
              margin: EdgeInsets.only(bottom: AppSpacing.xs),
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColor.whiteColor,
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                border: Border.all(color: AppColor.borderColor),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                    child: SizedBox(
                      height: AppSizes.px40,
                      width: AppSizes.px40,
                      child: ProductImageView(product: product),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
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
                        PriceLabel(
                          amount: product.price,
                          style: AppFonts.regular12(context)
                              .copyWith(color: AppColor.primaryColor),
                          iconSize: 12,
                          iconColor: AppColor.primaryColor,
                        ),
                      ],
                    ),
                  ),
                  AnimatedAddToCartIconButton(
                    size: AppDimensions.addToCartButtonAssistant,
                    onAdd: () async {
                      context.read<AssistantCubit>().recordProductInterest(
                        product,
                      );
                      context.read<CartCubit>().add(product);
                    },
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Icon(
                    DirectionAwareIcons.forward(context),
                    size: AppSizes.px18,
                    color: AppColor.greyColor,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
