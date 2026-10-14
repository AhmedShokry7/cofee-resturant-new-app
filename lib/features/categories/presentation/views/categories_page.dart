import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/categories/data/categories_list.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
import 'package:new_coffee/features/menu/data/menu_list.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/page_title.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = getCategoriesList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageTitle(title: "Categories"),
            const CategoryTabs(),
            Expanded(
              child: BlocBuilder<CategoriesCubit, CategoriesState>(
                builder: (context, state) {
                  final index = state.index.clamp(0, categories.length - 1);
                  return _CategoryProducts(category: categories[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryProducts extends StatelessWidget {
  const _CategoryProducts({required this.category});

  final CategoryModel category;

  @override
  Widget build(BuildContext context) {
    final products = getMenuList()
        .where((product) => product.category == category.label)
        .toList();
    if (products.isEmpty) {
      return EmptyState(
        icon: category.icon,
        title: "No products yet",
        subtitle: "Products in ${category.label} will appear here",
      );
    }
    return ProductsGridView(products: products);
  }
}
