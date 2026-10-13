import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/order_item_card.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/shipping_address_section.dart';

class CheckoutPageBody extends StatelessWidget {
  const CheckoutPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(SpacingTokens.lg.w),
      children: [
        const ShippingAddressSection(),
        SizedBox(height: SpacingTokens.lg.h),
        const Divider(),
        SizedBox(height: SpacingTokens.lg.h),
        Text("Order List", style: AppFonts.semiBold16(context)),
        SizedBox(height: SpacingTokens.md.h),
        BlocBuilder<CartCubit, CartState>(
          builder: (context, state) {
            return Column(
              children: state.items
                  .map((item) => OrderItemCard(product: item.product))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
