import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/shared/widgets/animated_add_to_cart_button.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class ProductDetailsBottomBar extends StatelessWidget {
  const ProductDetailsBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
      builder: (context, state) {
        final cubit = context.read<ProductDetailsCubit>();
        final unit = cubit.unitPrice;
        final note = state.note;
        final blocked = state.validationError;

        final total = unit * state.quantity;
        return Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColor.cardSurface,
            border: Border(top: BorderSide(color: AppColor.borderColor)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (blocked != null)
                Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    blocked,
                    style: AppFonts.regular12(context)
                        .copyWith(color: AppColor.errorColor),
                  ),
                ),
              // The success feedback lives inside the button: it shows
              // "Adding...", then a check, then returns to idle. No separate
              // SnackBar is shown for a successful add.
              Row(
                children: [
                  PriceLabel(
                    amount: total,
                    style: AppFonts.semiBold16(context)
                        .copyWith(color: AppColor.primaryColor),
                    iconSize: 16,
                    iconColor: AppColor.primaryColor,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AnimatedAddToCartButton(
                      label: state.isAvailable ? S.addToCart : S.unavailable,
                      // Disabled for an unavailable combination or an unmet
                      // admin rule, instead of accepting an order that the
                      // server would reject at checkout.
                      enabled: state.canAddToCart,
                      onAdd: () async {
                        final product = state.product;
                        if (product == null) return;
                        context.read<CartCubit>().add(
                          product,
                          quantity: state.quantity,
                          note: note,
                          optionValueIds: state.selection.valueIds,
                          unitPrice: unit,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
