import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_details_body.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_details_bottom_bar.dart';

class ProductDetailsPage extends StatelessWidget {
  const ProductDetailsPage({super.key, required this.product});

  static const routeName = "productDetailsRoute";

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductDetailsCubit(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text("Product Details"),
            actions: [
              BlocBuilder<FavoritesCubit, FavoritesState>(
                builder: (context, state) {
                  final isFavorite = state.ids.contains(product.id);
                  return IconButton(
                    onPressed: () =>
                        context.read<FavoritesCubit>().toggle(product.id),
                    icon: Icon(
                      HugeIcons.strokeRoundedFavourite,
                      color: isFavorite
                          ? AppColor.primaryColor
                          : AppColor.greyColor,
                    ),
                  );
                },
              ),
            ],
          ),
          body: ProductDetailsBody(product: product),
          bottomNavigationBar: ProductDetailsBottomBar(product: product),
        ),
      ),
    );
  }
}
