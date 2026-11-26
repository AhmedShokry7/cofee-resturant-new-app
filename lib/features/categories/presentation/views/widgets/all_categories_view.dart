import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/category_circle_item.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

/// The root of the category tree: every main category, nothing selected.
///
/// This is what "See all" opens beside the home category row. It reads the
/// catalogue the tab bar has already loaded and never the shared tab index,
/// so a category selected on an earlier visit cannot decide what this page
/// shows. Only rows with no parent belong here: a sub-category is reached
/// through its parent's products, the same way the catalogue tab reaches it.
class AllCategoriesView extends StatelessWidget {
  const AllCategoriesView({super.key, required this.onCategoryTap});

  /// Opens the products of the category the customer picked.
  final ValueChanged<CategoryModel> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CategoriesCubit>();
    return BlocBuilder<CategoriesCubit, CategoriesState>(
      builder: (context, state) {
        if (state.isLoading && state.categories.isEmpty) {
          return const CategoriesLoadingView();
        }
        // A failed load is not an empty catalogue: telling the customer the
        // shop has no categories after an unreachable backend blames the data
        // for a connection. The same shape the catalogue tab uses.
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
        final roots = [
          for (final category in state.categories)
            if (category.parentId == null) category,
        ];
        if (roots.isEmpty) {
          return EmptyState(icon: AppIcons.grid, title: S.noCategories);
        }
        return SingleChildScrollView(
          padding: AppLayout.pageBody,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              for (final category in roots)
                CategoryCircleItem(
                  category: category,
                  onTap: () => onCategoryTap(category),
                ),
            ],
          ),
        );
      },
    );
  }
}
