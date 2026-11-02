import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/category_grid_item.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_link.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section_title.dart';
import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class HomeCategoriesSection extends StatelessWidget {
  const HomeCategoriesSection({super.key});

  /// Tiles in one page of the grid and the rows it stacks. The skeleton that
  /// mirrors this section reads the same numbers, so the two cannot drift.
  static const int gridColumns = 4;
  static const int gridRows = 2;

  /// The gap between two tiles.
  static const double gap = AppSpacing.sm;

  /// The edge a tile gets inside [constraints]: the row shared between
  /// [gridColumns], never wider than the category tile ceiling.
  static double tileExtent(BoxConstraints constraints) {
    final slot = (constraints.maxWidth - (gridColumns - 1) * gap) / gridColumns;
    return slot > AppBreakpoints.categoryTileMaxWidth
        ? AppBreakpoints.categoryTileMaxWidth
        : slot;
  }

  /// The room the whole grid needs, so the page does not jump when it fills.
  static double gridHeight(BoxConstraints constraints) =>
      tileExtent(constraints) * AppDimensions.categoryTileAspect * gridRows +
      AppSpacing.md;

  /// Opens the catalogue tab on the tile the customer was looking at.
  ///
  /// Matched by stable id, not by position: the home grid and the categories tab
  /// load independently, so equal indices do not guarantee equal categories.
  void _openCategory(BuildContext context, String? categoryId) {
    if (categoryId == null) return;
    context.read<CategoriesCubit>().selectCategoryById(categoryId);
    context.read<MainCubit>().changeTab(MainTab.categories.index);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<HomeCubit>().state.categories;
    if (categories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: S.categories,
          titleStyle: AppFonts.semiBold18(context),
          trailing: HomeSectionLink(
            label: S.seeAll,
            onTap: () =>
                context.read<MainCubit>().changeTab(MainTab.categories.index),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = tileExtent(constraints);
            return SizedBox(
              height: gridHeight(constraints),
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridRows,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisExtent: itemWidth,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) => CategoryGridItem(
                  category: categories[index],
                  onTap: () => _openCategory(context, categories[index].id),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
