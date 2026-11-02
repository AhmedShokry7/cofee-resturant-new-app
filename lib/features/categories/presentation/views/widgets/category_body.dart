import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/bundles/presentation/views/widgets/bundle_list_tile.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_scoped_header.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

/// What one category is showing: its products, its bundles, or the state in
/// between.
///
/// [categoryId] pins the body to a single category and gives it the header that
/// names it, which is how a page opened from a banner answers for the category
/// the banner is about and nothing else. With no tabs in that mode there is
/// nothing to select, so the shared selection is left wherever the customer put
/// it - the catalogue tab is not changed by a banner nobody tapped on it.
class CategoryBody extends StatelessWidget {
  const CategoryBody({super.key, this.categoryId});

  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CategoriesCubit>();
    return BlocBuilder<CategoriesCubit, CategoriesState>(
      builder: (context, state) {
        // The catalogue tab follows the selected index; a page opened for one
        // category follows the id it was given. Which row that id is cannot be
        // looked up here - the cubit owns that rule.
        final index = categoryId == null
            ? (state.categories.isEmpty
                  ? null
                  : state.index.clamp(0, state.categories.length - 1))
            : cubit.indexOf(categoryId);
        return Column(
          children: [
            if (categoryId != null)
              CategoryScopedHeader(
                title: index == null
                    ? S.categories
                    : state.categories[index].label,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            Expanded(child: _contents(cubit, state, index)),
          ],
        );
      },
    );
  }

  Widget _contents(CategoriesCubit cubit, CategoriesState state, int? index) {
    if (state.isLoading && state.categories.isEmpty) {
      return const CategoriesLoadingView();
    }
    // A failed load is not an empty list. Reporting "no categories" after an
    // error claimed the catalogue was empty when it was in fact unreachable.
    if (state.error != null && state.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyState(
                icon: AppIcons.offline,
                title: S.couldNotLoadCategories,
              ),
              SizedBox(height: AppSpacing.md),
              CustomBtn(text: S.retry, onPressed: () => cubit.load()),
            ],
          ),
        ),
      );
    }
    if (state.categories.isEmpty) {
      return EmptyState(
        icon: AppIcons.grid,
        title: S.noCategories,
        subtitle: S.categoriesSoon,
      );
    }
    // The tabs are on screen and none of them carries the id this page was
    // opened for: the category was deleted or unpublished after the banner was
    // written. Not "no categories" - there are some, just not this one.
    if (index == null) {
      return EmptyState(icon: AppIcons.grid, title: S.categoryUnavailable);
    }
    final category = state.categories[index];

    // Bundle contents come from the bundles tab's own data rather than a
    // category product query, because a bundle is not a product row.
    if (cubit.isBundlesTab(index)) {
      return _BundlesList(
        bundles: state.bundles,
        productsById: {
          for (final product in state.products) product.id: product,
        },
      );
    }

    final products = cubit.productsAt(index);
    if (products.isEmpty) {
      return EmptyState(
        icon: category.icon,
        title: S.noProductsYet,
        subtitle: S.productsIn(category.label),
      );
    }
    return ProductsGridView(key: ValueKey(category.id), products: products);
  }
}

class _BundlesList extends StatelessWidget {
  const _BundlesList({required this.bundles, required this.productsById});

  final List<BundleModel> bundles;
  final Map<String, ProductModel> productsById;

  @override
  Widget build(BuildContext context) {
    if (bundles.isEmpty) {
      return EmptyState(
        icon: AppIcons.bundle,
        title: S.noBundles,
        subtitle: S.bundlesHint,
      );
    }
    return ListView.builder(
      padding: AppLayout.pageBody,
      itemCount: bundles.length,
      itemBuilder: (context, index) =>
          BundleListTile(bundle: bundles[index], productsById: productsById),
    );
  }
}
