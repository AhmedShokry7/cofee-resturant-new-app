import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

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

        // Quantity and price live in the page content now; this bar only
        // submits them. state.quantity is the single source of truth.
        return Container(
          padding: EdgeInsets.all(SpacingTokens.lg.w),
          decoration: const BoxDecoration(
            color: AppColor.whiteColor,
            border: Border(top: BorderSide(color: AppColor.borderColor)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (blocked != null)
                Padding(
                  padding: EdgeInsets.only(bottom: SpacingTokens.sm.h),
                  child: Text(
                    blocked,
                    style: AppFonts.regular12(context)
                        .copyWith(color: AppColor.errorColor),
                  ),
                ),
              CustomBtn(
                text: state.isAvailable ? S.addToCart : S.unavailable,
                // Disabled for an unavailable combination or an unmet
                // admin rule, instead of accepting an order that the
                // server would reject at checkout.
                onPressed: state.canAddToCart
                    ? () {
                        final product = state.product;
                        if (product == null) return;
                        context.read<CartCubit>().add(
                          product,
                          quantity: state.quantity,
                          note: note,
                          optionValueIds: state.selection.valueIds,
                          unitPrice: unit,
                        );
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(S.addedToCart)));
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
