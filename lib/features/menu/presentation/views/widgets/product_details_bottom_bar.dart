import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/product_variants.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class ProductDetailsBottomBar extends StatelessWidget {
  const ProductDetailsBottomBar({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
      builder: (context, state) {
        final extras = extrasFor(
          product,
        ).where((extra) => state.extraIds.contains(extra.id)).toList();
        final sized = hasSizes(product);
        final unit = unitPrice(
          product,
          size: sized ? state.size : null,
          extras: extras,
        );
        final total = unit * state.quantity;
        final note = sized || extras.isNotEmpty
            ? variantNote(
                size: sized ? state.size : null,
                sugar: hasSugarChoice(product) ? state.sugar : null,
                extras: extras,
              )
            : '';
        return Container(
          padding: EdgeInsets.all(SpacingTokens.lg.w),
          decoration: const BoxDecoration(
            color: AppColor.whiteColor,
            border: Border(top: BorderSide(color: AppColor.borderColor)),
          ),
          child: Row(
            children: [
              _QuantityStepper(
                quantity: state.quantity,
                onIncrement: () =>
                    context.read<ProductDetailsCubit>().incrementQuantity(),
                onDecrement: () =>
                    context.read<ProductDetailsCubit>().decrementQuantity(),
              ),
              SizedBox(width: SpacingTokens.md.w),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Price",
                      style: AppFonts.regular12(
                        context,
                      ).copyWith(color: AppColor.greyColor),
                    ),
                    Text(
                      Formatters.price(total),
                      style: AppFonts.semiBold18(context),
                    ),
                  ],
                ),
              ),
              SizedBox(width: SpacingTokens.md.w),
              Expanded(
                flex: 2,
                child: CustomBtn(
                  text: "Add to Cart",
                  onPressed: () {
                    context.read<CartCubit>().add(
                      product,
                      quantity: state.quantity,
                      note: note,
                      unitPrice: unit,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Added to cart")),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColor.borderColor),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove),
            color: AppColor.primaryColor,
            iconSize: 18.w,
            padding: EdgeInsets.all(SpacingTokens.xs.w),
            constraints: const BoxConstraints(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: SpacingTokens.xs.w),
            child: Text('$quantity', style: AppFonts.semiBold16(context)),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add),
            color: AppColor.primaryColor,
            iconSize: 18.w,
            padding: EdgeInsets.all(SpacingTokens.xs.w),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

