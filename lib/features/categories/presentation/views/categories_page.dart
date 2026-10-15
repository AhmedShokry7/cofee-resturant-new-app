import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/bundles/presentation/views/widgets/bundle_list_tile.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/page_title.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageTitle(title: "Categories"),
            const CategoryTabs(),
            Expanded(
              child: BlocBuilder<CategoriesCubit, CategoriesState>(
                builder: (context, state) {
                  if (state.isLoading && state.categories.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.categories.isEmpty) {
                    return const EmptyState(
                      icon: Icons.category_outlined,
                      title: "No categories yet",
                      subtitle: "Categories will appear here once they are added",
                    );
                  }
                  final index = state.index.clamp(0, state.categories.length - 1);
                  final category = state.categories[index];

                  // Bundle contents come from the bundles tab's own data
                  // rather than a category product query, because a bundle is
                  // not a product row.
                  if (context.read<CategoriesCubit>().isBundlesTab(index)) {
                    return _BundlesList(bundles: state.bundles);
                  }

                  final products = context.read<CategoriesCubit>().productsAt(index);
                  if (products.isEmpty) {
                    return EmptyState(
                      icon: category.icon,
                      title: "No products yet",
                      subtitle: "Products in ${category.label} will appear here",
                    );
                  }
                  return ProductsGridView(products: products);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BundlesList extends StatelessWidget {
  const _BundlesList({required this.bundles});

  final List<BundleModel> bundles;

  @override
  Widget build(BuildContext context) {
    if (bundles.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: "No bundles yet",
        subtitle: "Bundles will appear here once they are added",
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      itemCount: bundles.length,
      itemBuilder: (context, index) =>
          BundleListTile(bundle: bundles[index]),
    );
  }
}