import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';

/// The cart tab carries the item count, so it rebuilds with the cart alone
/// rather than with every tab bar rebuild.
class CartTabIcon extends StatelessWidget {
  const CartTabIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        const icon = Icon(HugeIcons.strokeRoundedShoppingCart01);
        if (cartState.count == 0) return icon;
        return Badge(label: Text('${cartState.count}'), child: icon);
      },
    );
  }
}
