import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
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
      create: (context) => ProductDetailsCubit(
        repository: context.read<CatalogRepository>(),
        productId: product.id,
        branchId: context.read<BranchCubit>().state.selected?.id,
        initialProduct: product,
      ),
      child: Builder(
        builder: (context) => BlocListener<BranchCubit, BranchState>(
          listenWhen: (previous, current) =>
              previous.selected?.id != current.selected?.id,
          listener: (context, state) =>
              context.read<ProductDetailsCubit>().setBranch(state.selected?.id),
          child: Scaffold(
            appBar: AppBar(
              title: Text(S.productDetails),
              actions: [
                BlocBuilder<FavoritesCubit, FavoritesState>(
                  builder: (context, state) {
                    final isFavorite = state.ids.contains(product.id);
                    // Same contract as the shared ProductFavoriteButton:
                    // outlined grey heart when idle, completely filled red
                    // heart when saved.
                    return IconButton(
                      onPressed: () =>
                          context.read<FavoritesCubit>().toggle(product.id),
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite
                            : HugeIcons.strokeRoundedFavourite,
                        color: isFavorite
                            ? AppColor.errorColor
                            : AppColor.greyColor,
                      ),
                    );
                  },
                ),
              ],
            ),
            body: const ProductDetailsBody(),
            bottomNavigationBar: const ProductDetailsBottomBar(),
          ),
        ),
      ),
    );
  }
}
