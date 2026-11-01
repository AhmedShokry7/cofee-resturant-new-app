import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/page_title.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<FavoritesCubit, FavoritesState>(
          // A heart that could not be saved on the server must say so: the
          // list is otherwise shown as if the server had it.
          listenWhen: (previous, current) =>
              current.error != null && current.error != previous.error,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.error!)));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageTitle(title: S.favorites),
              Expanded(
                child: BlocBuilder<FavoritesCubit, FavoritesState>(
                  builder: (context, state) {
                    if (state.isLoading && state.favoriteProducts.isEmpty) {
                      return const ProductsGridSkeleton();
                    }
                    final items = state.favoriteProducts;
                    if (items.isEmpty) {
                      return EmptyState(
                        icon: AppIcons.favourite,
                        title: S.noFavorites,
                        subtitle: S.favoritesHint,
                      );
                    }
                    return ProductsGridView(products: items);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
