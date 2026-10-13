import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cart")),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          if (state.isEmpty) {
            return const EmptyState(
              icon: HugeIcons.strokeRoundedShoppingCart01,
              title: "Your cart is empty",
              subtitle: "Add your favorite coffee from the menu",
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(SpacingTokens.lg.w),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return ProductCard(
                      product: item.product,
                      quantity: item.quantity,
                      showFavorite: false,
                      onIncrement: () =>
                          context.read<CartCubit>().increment(item.product.id),
                      onDecrement: () =>
                          context.read<CartCubit>().decrement(item.product.id),
                    );
                  },
                ),
              ),
              _CartSummary(total: state.total),
            ],
          );
        },
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SpacingTokens.lg.w),
      decoration: const BoxDecoration(
        color: AppColor.whiteColor,
        border: Border(top: BorderSide(color: AppColor.borderColor)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total",
                style: AppFonts.regular16(
                  context,
                ).copyWith(color: AppColor.greyColor),
              ),
              Text(
                Formatters.price(total),
                style: AppFonts.semiBold20(
                  context,
                ).copyWith(color: AppColor.primaryColor),
              ),
            ],
          ),
          SizedBox(height: SpacingTokens.md.h),
          CustomBtn(
            text: "Checkout",
            onPressed: () =>
                Navigator.of(context).pushNamed(CheckoutPage.routeName),
          ),
        ],
      ),
    );
  }
}
