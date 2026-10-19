import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/bundles/presentation/views/widgets/bundle_list_tile.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/page_title.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CategoriesCubit>();
    cubit.ensureLoaded();
    if (initialCategoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await cubit.stream.firstWhere((state) => !state.isLoading);
        } catch (_) {}
        if (!cubit.isClosed) {
          cubit.selectCategoryById(initialCategoryId);
        }
      });
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageTitle(title: S.categories),
            const CategoryTabs(),
            Expanded(
              child: BlocBuilder<CategoriesCubit, CategoriesState>(
                builder: (context, state) {
                  if (state.isLoading && state.categories.isEmpty) {
                    return const CategoriesLoadingView();
                  }
                  // A failed load is not an empty list. Reporting "no
                  // categories" after an error claimed the catalogue was empty
                  // when it was in fact unreachable.
                  if (state.error != null && state.categories.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(SpacingTokens.lg.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EmptyState(
                              icon: Icons.cloud_off_outlined,
                              title: S.couldNotLoadCategories,
                            ),
                            SizedBox(height: SpacingTokens.md.h),
                            CustomBtn(
                              text: S.retry,
                              onPressed: () => cubit.load(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state.categories.isEmpty) {
                    return EmptyState(
                      icon: Icons.category_outlined,
                      title: S.noCategories,
                      subtitle: S.categoriesSoon,
                    );
                  }
                  final index = state.index.clamp(
                    0,
                    state.categories.length - 1,
                  );
                  final category = state.categories[index];

                  // Bundle contents come from the bundles tab's own data
                  // rather than a category product query, because a bundle is
                  // not a product row.
                  if (context.read<CategoriesCubit>().isBundlesTab(index)) {
                    return _BundlesList(
                      bundles: state.bundles,
                      productsById: {
                        for (final product in state.products)
                          product.id: product,
                      },
                    );
                  }

                  final products = context.read<CategoriesCubit>().productsAt(
                    index,
                  );
                  if (products.isEmpty) {
                    return EmptyState(
                      icon: category.icon,
                      title: S.noProductsYet,
                      subtitle: S.productsIn(category.label),
                    );
                  }
                   return ProductsGridView(
                     key: ValueKey(category.id),
                     products: products,
                   );
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
  const _BundlesList({required this.bundles, required this.productsById});

  final List<BundleModel> bundles;
  final Map<String, ProductModel> productsById;

  @override
  Widget build(BuildContext context) {
    if (bundles.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: S.noBundles,
        subtitle: S.bundlesHint,
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
          BundleListTile(bundle: bundles[index], productsById: productsById),
    );
  }
}
