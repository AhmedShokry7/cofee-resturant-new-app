import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/page_title.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageTitle(title: "Favorites"),
            Expanded(
              child: BlocBuilder<FavoritesCubit, FavoritesState>(
                builder: (context, state) {
                  if (state.isLoading && state.favoriteProducts.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = state.favoriteProducts;
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: HugeIcons.strokeRoundedFavourite,
                      title: "No favorites yet",
                      subtitle: "Tap the heart on any coffee to save it here",
                    );
                  }
                  return ProductsGridView(products: items);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
